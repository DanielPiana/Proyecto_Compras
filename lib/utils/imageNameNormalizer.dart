import 'dart:math';

String imageNameNormalizer(String input) {
  // 1. Trim y capitalize por palabra
  String formatted = input.trim().split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');

  // 2. Quitar acentos manualmente (100% compatible en Windows, Android, Linux, etc.)
  const accents = 'áàäâÁÀÄÂéèëêÉÈËÊíìïîÍÌÏÎóòöôÓÒÖÔúùüûÚÙÜÛñÑçÇ';
  const replacements = 'aaaaAAAAeeeeEEEEiiiiIIIIooooOOOOuuuuUUUUnNcC';

  String withoutAccents = formatted.split('').map((char) {
    final index = accents.indexOf(char);
    return index != -1 ? replacements[index] : char;
  }).join('');

  // 3. Mantener solo letras, números y espacios
  String safe = withoutAccents.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');

  // 4. Reemplazar espacios por _
  safe = safe.replaceAll(' ', '_');

  // 5. Añadir random de 4 dígitos
  final randomNumber = Random().nextInt(9999).toString().padLeft(4, '0');

  return '${safe}_$randomNumber';
}
