import 'package:flutter/cupertino.dart';

class DetalleRecetaProvider extends ChangeNotifier {
  int _pasoActualParaActualizar = 1;
  bool _estaEditando = false;
  String _nuevoTituloPaso = '';
  String _nuevaDescripcionPaso = '';
  bool _hayCambios = false;

  // GETTERS
  bool get estaEditando => _estaEditando;
  bool get hayCambiosProvider => _hayCambios;
  int get pasoActualParaActualizar => _pasoActualParaActualizar;
  String get nuevoTituloPaso => _nuevoTituloPaso;
  String get nuevaDescripcionPaso => _nuevaDescripcionPaso;


  void sumarPaso() {
    _pasoActualParaActualizar ++;
  }
  void restarPaso() {
    _pasoActualParaActualizar --;
  }

  void setEdicion(bool edicion){
    _estaEditando = edicion;
    notifyListeners();
  }

  void actualizarCambios(bool cambios) {
    _hayCambios = cambios;
    notifyListeners();
  }

  void actualizarPasoParaActualizar(int paso) {
    _pasoActualParaActualizar = paso;
    notifyListeners();
  }

  void cambioEstadoEdicion(bool bool) {
    _estaEditando = bool;
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
}