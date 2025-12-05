import 'package:flutter/cupertino.dart';

/// Provider que gestiona el estado de edición de los detalles de una receta
/// incluyendo pasos, nombre, foto y control de cambios
class RecipeDetailProvider extends ChangeNotifier {
  int _currentStepToUpdate = 1;
  bool _isEditing = false;
  String _newStepTitle = '';
  String _newStepDescription = '';

  bool _nameChanged = false;
  bool _photoChanged = false;
  bool _stepChanged = false;

  bool get isEditing => _isEditing;
  int get currentStepToUpdate => _currentStepToUpdate;
  String get newStepTitle => _newStepTitle;
  String get newStepDescription => _newStepDescription;

  bool get nameChanged => _nameChanged;
  bool get photoChanged => _photoChanged;
  bool get stepChanged => _stepChanged;

  /// Incrementa el número del paso actual
  void incrementStep() {
    _currentStepToUpdate++;
  }

  /// Decrementa el número del paso actual
  void decrementStep() {
    _currentStepToUpdate--;
  }

  /// Activa o desactiva el modo de edición
  void setEditing(bool editing) {
    _isEditing = editing;
    notifyListeners();
  }

  /// Alterna el estado de edición
  void toggleEditingState(bool value) {
    _isEditing = value;
    notifyListeners();
  }

  /// Actualiza el número del paso actual
  void updateCurrentStep(int step) {
    _currentStepToUpdate = step;
    notifyListeners();
  }

  /// Actualiza el título del nuevo paso
  void updateNewTitle(String newTitle) {
    _newStepTitle = newTitle;
    notifyListeners();
  }

  /// Actualiza la descripción del nuevo paso
  void updateNewDescription(String newDescription) {
    _newStepDescription = newDescription;
    notifyListeners();
  }

  /// Establece el título del paso
  void setNewTitle(String title) {
    _newStepTitle = title;
    notifyListeners();
  }

  /// Establece la descripción del paso
  void setNewDescription(String description) {
    _newStepDescription = description;
    notifyListeners();
  }

  /// Marca que el nombre de la receta ha cambiado
  void setNameChanged(bool value) {
    _nameChanged = value;
    notifyListeners();
  }

  /// Marca que la foto de la receta ha cambiado
  void setPhotoChanged(bool value) {
    _photoChanged = value;
    notifyListeners();
  }

  /// Marca que un paso de la receta ha cambiado
  void setStepChanged(bool value) {
    _stepChanged = value;
    notifyListeners();
  }

  /// Resetea todos los cambios y sale del modo edición
  void resetChanges() {
    _nameChanged = false;
    _photoChanged = false;
    _stepChanged = false;
    _isEditing = false;
    notifyListeners();
  }
}