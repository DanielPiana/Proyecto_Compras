import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

class Compra extends StatefulWidget {
  final Database database;

  const Compra({super.key, required this.database});

  @override
  State<Compra> createState() => _CompraState();
}

class _CompraState extends State<Compra> {
  // LISTA PARA ALMACENAR LOS PRODUCTOS AGRUPADOS POR SUPERMERCADO
  List<Map<String, dynamic>> _productosCompra = [];

  // VARIABLE PARA ALMACENAR EL PRECIO TOTAL DE LOS PRODUCTOS MARCADOS
  double _totalMarcados = 0.0;

  @override
  void initState() {
    super.initState();
    // CARGAR LOS PRODUCTOS Y CALCULAR EL TOTAL DE LOS PRODUCTOS MARCADOS AL INICIAR
    _cargarCompra();
  }

  /*TODO-----------------METODO DE CARGAR COMPRA-----------------*/
  Future<void> _cargarCompra() async {
    // CONSULTA SQL QUE OBTIENE LOS PRODUCTOS DE LA COMPRA,
    // JUNTO CON EL SUPERMERCADO DE CADA PRODUCTO
    final productos = await widget.database.rawQuery('''
    SELECT compra.*, productos.supermercado 
    FROM compra 
    INNER JOIN productos ON compra.idProducto = productos.id
  ''');

    // AGRUPAMOS LOS PRODUCTOS POR SUPERMERCADO
    final Map<String, List<Map<String, dynamic>>> agrupados = {};

    // ITERAMOS SOBRE CADA PRODUCTO OBTENIDO DE LA CONSULTA
    for (var producto in productos) {

      // OBTENEMOS EL NOMBRE DEL SUPERMERCADO; SI ES NULO, USAMOS 'Sin supermercado'
      final supermercado = (producto['supermercado'] ?? 'Sin supermercado').toString();

      // SI EL SUPERMERCADO NO EXISTE COMO CLAVE EN EL MAPA, LO AÑADIMOS AL MAPA COMO UNA LISTA VACÍA
      if (!agrupados.containsKey(supermercado)) {
        agrupados[supermercado] = [];
      }
      // AGREGAMOS EL PRODUCTO A LA LISTA CORRESPONDIENTE DENTRO DEL MAPA
      agrupados[supermercado]?.add(producto);
    }

    // ACTUALIZAMOS EL ESTADO CON LOS PRODUCTOS AGRUPADOS PARA REFLEJARLO EN LA INTERFAZ
    setState(() {
      _productosCompra = agrupados.entries.map((entry) {
        return {
          'supermercado': entry.key, // NOMBRE DEL SUPERMERCADO
          'productos': entry.value, // LISTA DE PRODUCTOS DE ESE SUPERMERCADO
        };
      }).toList();
    });

    _calcularTotalMarcados(); // ACTUALIZA EL TOTAL DE LOS PRODUCTOS MARCADOS
  }

  /*TODO-----------------METODO CALCULAR TOTAL MARCADO-----------------*/
  Future<void> _calcularTotalMarcados() async {
    // CONSULTA PARA OBTENER LA SUMA DE LOS PRECIOS DE LOS PRODUCTOS MARCADOS
    final resultado = await widget.database.rawQuery(
      'SELECT SUM(precio) as total FROM compra WHERE marcado = 1',
    );
    setState(() {
      // SI NO HAY RESULTADOS EN LA CONSULTA, EL RESULTADO SERA 0.0
      _totalMarcados = (resultado.isNotEmpty && resultado[0]['total'] != null)
          ? (resultado[0]['total'] as num).toDouble()
          : 0.0;
    });
  }

  /*TODO-----------------METODO GENERAR FACTURA-----------------*/
  Future<void> _generarFactura() async {
    // CONSULTA PARA OBTENER TODOS LOS PRODUCTOS MARCADOS
    final productosMarcados = await widget.database.rawQuery(
      'SELECT * FROM compra WHERE marcado = 1',
    );
    // SI NO HAY RESULTADOS EN LA CONSULTA MOSTRAMOS UN MENSAJE DE ERROR
    if (productosMarcados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos marcados para generar una factura.')),
      );
      return;
    }

    // CALCULAMOS EL PRECIO TOTAL DE LOS PRODUCTOS MARCADOS
    double precioTotal = productosMarcados.fold(0.0, (sum, producto) {
      return sum + (producto['precio'] as num).toDouble();
    });

    // OBTENEMOS SOLO LA FECHA DEL DateTime.now
    // ([0] INDICA EL PRIMER INDICE DE LA LISTA QUE SE GENERA AL USAR SPLIT)
    final fechaString = DateTime.now().toIso8601String().split('T')[0];

    // PARSEAMOS A UN FORMATO CON SENTIDO PARA EL 90% DE LA POBLACION
    final fechaActual = DateFormat("dd/MM/yyyy").format(DateTime.parse(fechaString));

    // INSERTAMOS LA NUEVA FACTURA
    final idFactura = await widget.database.insert('facturas', {
      'precio': precioTotal,
      'fecha': fechaActual, // INSERTAMOS LA FECHA SIMPLIFICADA
      'supermercado': 'Supermercado Desconocido',
    });

    // ITERAMOS SOBRE CADA PRODUCTO MARCADO OBTENIDO DE LA CONSULTA
    for (var producto in productosMarcados) {
      await widget.database.insert(
          'producto_factura', { // NOMBRE DE LA TABLA DONDE INSERTAMOS
        'idProducto': producto['idProducto'], //idProducto no cambia
        'idFactura': idFactura, // LO ASOCIAMOS CON EL idFactura
        'cantidad': 1, // TODO CANTIDAD EN LA SIGUIENTE ACTUALIZACION
      });
    }

    // MOSTRAMOS MENSAJE DE CONFIRMACION
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Factura generada correctamente.')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista de la Compra"), // TITULO DEL AppBar
        centerTitle: true,
        actions: [
          IconButton( // ICONO PARA GENERAR FACTURAS
            icon: const Icon(Icons.receipt),
            onPressed: _generarFactura,
            tooltip: 'Generar Factura',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded( // EXPANDED PARA QUE EL ListView.Builder NO DE ERROR
            child: ListView.builder(
              // TAMAÑO EN BASE A LA CANTIDAD DE SUPERMERCADOS QUE HAY
              itemCount: _productosCompra.length,
              itemBuilder: (context, index) {
                // OBTENEMOS UN ELEMENTO DE LA LISTA BASANDONOS EN EL INDICE
                final grupo = _productosCompra[index];
                // OBTENEMOS EL SUPERMERCADO DE ESE ELEMENTO
                final supermercado = grupo['supermercado'];
                // OBTENEMOS LA LISTA DE PRODUCTOS DE ESE SUPERMERCADO
                final productos = grupo['productos'] as List<Map<String, dynamic>>;

                return ExpansionTile( // "CARPETAS"
                  title: Text(supermercado,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  children: productos.map((producto) {
                    return ListTile(
                      leading: IconButton( // BOTON PARA MARCAR Y DESMARCAR PRODUCTO
                        icon: Icon( // SI producto['marcado'] ES 1, PONEMOS UN ESTILO Y SI NO, OTRO
                          producto['marcado'] == 1
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: producto['marcado'] == 1
                              ? Colors.green
                              : Colors.grey,
                        ),
                        onPressed: () async {
                          // ALTERNA EL ESTADO MARCADO DEL PRODUCTO
                          final nuevoEstado = producto['marcado'] == 1 ? 0 : 1;
                          // ACTUALIZAMOS EN LA BASE DE DATOS EL ATRIBUTO MARCADO DEL PRODUCTO
                          await widget.database.rawUpdate(
                            'UPDATE compra SET marcado = ? WHERE idProducto = ?',
                            [nuevoEstado, producto['idProducto']],
                          );
                          // ACTUALIZAMOS LA INTERFAZ
                          _cargarCompra();
                        },
                      ),
                      title: Text(producto['nombre']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min, // HACEMOS QUE OCUPE LO NECESARIO
                        children: [
                          Text( // FORMATEAMOS EL PRECIO A STRING PARA VISUALIZARLO BIEN
                            '\$${producto['precio'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton( // ICONO PARA BORRAR EL PRODUCTO DE LA LISTA DE LA COMPRA
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              // CONSULTA PARA BORRAR EL PRODUCTO DE LA TABLA
                              await widget.database.rawDelete(
                                'DELETE FROM compra WHERE idProducto = ?',
                                [producto['idProducto']],
                              );
                              // ACTUALIZAMOS LA INTERFAZ
                              _cargarCompra();
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16),
            child: Row(
              // USAMOS spaceBetween PARA QUE SALGA UN Text AL PRINCIPIO Y OTRO AL FINAL
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total marcado:",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text( // FORMATEAMOS EL PRECIO PARA VISUALIZARLO BIEN
                  '\$${_totalMarcados.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
