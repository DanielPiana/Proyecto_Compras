import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

void showAwesomeSnackBar(
    BuildContext context, {
      required String title,
      required String message,
      required asc.ContentType contentType,
      Color? color,
    }) {
  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    content: asc.AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: contentType,
      color: color,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
