import 'package:flutter/cupertino.dart';

class DetalleRecetaProvider extends ChangeNotifier {
  int _pasoActualParaActualizar = 1;
  bool _estaEditando = false;
  String _nuevoTituloPaso = '';
  String _nuevaDescripcionPaso = '';

  bool _cambioNombre = false;
  bool _cambioFoto = false;
  bool _cambioPaso = false;

  bool get estaEditando => _estaEditando;
  int get pasoActualParaActualizar => _pasoActualParaActualizar;
  String get nuevoTituloPaso => _nuevoTituloPaso;
  String get nuevaDescripcionPaso => _nuevaDescripcionPaso;

  bool get cambioNombre => _cambioNombre;
  bool get cambioFoto => _cambioFoto;
  bool get cambioPaso => _cambioPaso;

  void sumarPaso() {
    _pasoActualParaActualizar++;
  }

  void restarPaso() {
    _pasoActualParaActualizar--;
  }

  void setEdicion(bool edicion) {
    _estaEditando = edicion;
    notifyListeners();
  }

  void cambioEstadoEdicion(bool value) {
    _estaEditando = value;
    notifyListeners();
  }

  void actualizarPasoParaActualizar(int paso) {
    _pasoActualParaActualizar = paso;
    notifyListeners();
  }

  void actualizarNuevoTitulo(String nuevo) {
    _nuevoTituloPaso = nuevo;
    notifyListeners();
  }

  void actualizarNuevaDescripcion(String nueva) {
    _nuevaDescripcionPaso = nueva;
    notifyListeners();
  }

  void setNuevoTitulo(String titulo) {
    _nuevoTituloPaso = titulo;
    notifyListeners();
  }

  void setNuevaDescripcion(String descripcion) {
    _nuevaDescripcionPaso = descripcion;
    notifyListeners();
  }

  void setCambioNombre(bool value) {
    _cambioNombre = value;
    print("booleana cambio nombre: $_cambioNombre");
    notifyListeners();
  }

  void setCambioFoto(bool value) {
    _cambioFoto = value;
    print("booleana cambio foto: $_cambioFoto");
    notifyListeners();
  }

  void setCambioPaso(bool value) {
    _cambioPaso = value;
    print("booleana cambio paso: $_cambioPaso");
    notifyListeners();
  }

  void resetCambios() {
    _cambioNombre = false;
    _cambioFoto = false;
    _cambioPaso = false;
    _estaEditando = false;
    notifyListeners();
  }
}
