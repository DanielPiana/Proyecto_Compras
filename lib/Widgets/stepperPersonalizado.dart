import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/detalleRecetaProvider.dart';
import '../models/PasoReceta.dart';

class StepperPersonalizado extends StatefulWidget {
  final List<PasoReceta> pasosReceta;

  const StepperPersonalizado({
    super.key,
    required this.pasosReceta,
  });

  @override
  State<StepperPersonalizado> createState() => _StepperPersonalizadoState();
}

class _StepperPersonalizadoState extends State<StepperPersonalizado> {
  int pasoActual = 0;

  String tituloOriginal = "";
  String descripcionOriginal = "";

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _focusNode = FocusNode();

  bool _ultimoEstadoEdicion = false;

  @override
  void initState() {
    super.initState();
    _tituloController.text = widget.pasosReceta.first.titulo;
    _descripcionController.text = widget.pasosReceta.first.descripcion;

    final provider = context.read<DetalleRecetaProvider>();

    provider.addListener(() {
      if (!_ultimoEstadoEdicion && provider.estaEditando) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _focusNode.requestFocus();
          }
        });
      }
      _ultimoEstadoEdicion = provider.estaEditando;
    });
  }

  void _resetProvider() {
    final provider = context.read<DetalleRecetaProvider>();
    provider.cambioEstadoEdicion(false);
    provider.setNuevaDescripcion('');
    provider.setNuevoTitulo('');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DetalleRecetaProvider>();

    return Column(
      children: [
        // Card con el contenido del paso actual
        SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicador del paso actual
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Paso ${pasoActual + 1} de ${widget.pasosReceta.length}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 400),
                    crossFadeState:
                        context.watch<DetalleRecetaProvider>().estaEditando
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                    firstChild: Column(
                      children: [
                        Center(
                          child: Text(
                            widget.pasosReceta[pasoActual].titulo,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.pasosReceta[pasoActual].descripcion,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    secondChild: Column(
                      children: [
                        Center(
                          child: TextField(
                            controller: _tituloController,
                            focusNode: _focusNode,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: "Título",
                            ),
                            onChanged: (value) {
                                provider.setNuevoTitulo(value);
                                if (value != tituloOriginal) {
                                  provider.actualizarCambios(true);
                                } else {
                                  provider.actualizarCambios(false);
                                }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _descripcionController,
                          maxLines: null,
                          decoration: const InputDecoration(
                            labelText: "Descripción",
                          ),
                          onChanged: (value) {
                              provider.setNuevaDescripcion(value);
                              if (value != descripcionOriginal) {
                                provider.actualizarCambios(true);
                              }else {
                                provider.actualizarCambios(false);
                              }
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Indicadores de puntos (dots)
        _buildPageIndicator(),

        const SizedBox(height: 16),

        // Botones de navegación
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: pasoActual > 0
                    ? () {
                  setState(() {
                    pasoActual--;
                    _tituloController.text = widget.pasosReceta[pasoActual].titulo;
                    _descripcionController.text =
                        widget.pasosReceta[pasoActual].descripcion;
                    _ultimoEstadoEdicion = false;
                    provider.setEdicion(false);
                    print(pasoActual+1);
                    provider.restarPaso();
                  });
                  _resetProvider();
                }
                    : null,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text("Anterior"),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      pasoActual > 0 ? Colors.grey[600] : Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: pasoActual < widget.pasosReceta.length - 1
                    ? () {
                  setState(() {
                    pasoActual++;
                    _tituloController.text = widget.pasosReceta[pasoActual].titulo;
                    _descripcionController.text =
                        widget.pasosReceta[pasoActual].descripcion;
                    _ultimoEstadoEdicion = false;
                    provider.setEdicion(false);
                    print(pasoActual+1);
                    provider.sumarPaso;
                  });
                  _resetProvider();
                }
                    : null,
                icon: Icon(
                  pasoActual == widget.pasosReceta.length - 1
                      ? Icons.check
                      : pasoActual == widget.pasosReceta.length - 2
                          ? Icons.flag
                          : Icons.arrow_forward,
                  size: 16,
                ),
                label: Text(pasoActual == widget.pasosReceta.length - 1
                    ? "Finalizado"
                    : pasoActual == widget.pasosReceta.length - 2
                        ? "Finalizar"
                        : "Siguiente"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pasoActual == widget.pasosReceta.length - 1
                      ? Colors.green
                      : Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget para crear los puntos indicadores
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.pasosReceta.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == pasoActual ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: index == pasoActual
                ? Colors.blue
                : index < pasoActual
                    ? Colors.green.withOpacity(0.6)
                    : Colors.grey.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
