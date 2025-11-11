String normalizeText(String text) {
  final map = {
    'á':'a', 'é':'e', 'í':'i', 'ó':'o', 'ú':'u',
    'Á':'a', 'É':'e', 'Í':'i', 'Ó':'o', 'Ú':'u',
    'ñ':'n', 'Ñ':'n',
  };

  return text
      .toLowerCase()
      .split('')
      .map((c) => map[c] ?? c)
      .join();
}
