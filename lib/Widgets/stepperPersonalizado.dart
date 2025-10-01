import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/detalleRecetaProvider.dart';
import '../Providers/pasosRecetaProvider.dart';
import '../l10n/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final providerDetalle = context.read<DetalleRecetaProvider>();
    // CARGAMOS PASOS DESDE EL PROVIDER
    final pasos = context.watch<PasosRecetaProvider>().pasos;

    if (pasos.isEmpty) {
      if (pasoActual != 0) {
        setState(() {
          pasoActual = 0;
          _tituloController.text = '';
          _descripcionController.text = '';
        });
      }
    } else if (pasoActual >= pasos.length) {
      setState(() {
        pasoActual = pasos.length - 1;
        _tituloController.text = pasos[pasoActual].titulo;
        _descripcionController.text = pasos[pasoActual].descripcion;
      });
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600, width: 0.8),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${AppLocalizations.of(context)!.step}: ${pasos.isEmpty ? 0 : pasoActual + 1} de ${pasos.length}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  crossFadeState: context.watch<DetalleRecetaProvider>().estaEditando
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: (pasos.isEmpty)
                      ? const SizedBox.shrink()
                      : Column(
                    children: [
                      Center(
                        child: Text(
                          pasos[pasoActual].titulo,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pasos[pasoActual].descripcion,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  secondChild: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        TextField(
                          controller: _tituloController,
                          focusNode: _focusNode,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.title,
                          ),
                          onChanged: (value) {
                            if (pasos.isEmpty) return;
                            final actualizado =
                            pasos[pasoActual].copyWith(titulo: value);
                            context
                                .read<PasosRecetaProvider>()
                                .actualizarPasoLocal(
                                actualizado.numeroPaso, actualizado);
                            providerDetalle.setCambioPaso(true);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descripcionController,
                          maxLines: null,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.description,
                          ),
                          onChanged: (value) {
                            if (pasos.isEmpty) return;
                            final actualizado =
                            pasos[pasoActual].copyWith(descripcion: value);
                            context
                                .read<PasosRecetaProvider>()
                                .actualizarPasoLocal(
                                actualizado.numeroPaso, actualizado);
                            providerDetalle.setCambioPaso(true);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),


                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        final pProv = context.read<PasosRecetaProvider>();
                        pProv.crearPaso("", "");
                        final nuevos = pProv.pasos;
                        setState(() {
                          pasoActual = nuevos.isEmpty ? 0 : nuevos.length - 1;
                          _tituloController.text =
                          nuevos.isNotEmpty ? nuevos.last.titulo : "";
                          _descripcionController.text =
                          nuevos.isNotEmpty ? nuevos.last.descripcion : "";
                        });
                        context.read<DetalleRecetaProvider>().setEdicion(true);
                      },
                      child: Text(AppLocalizations.of(context)!.add_step),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () async {
                        final pProv = context.read<PasosRecetaProvider>();
                        if (pProv.pasos.isEmpty) return;
                        final paso = pProv.pasos[pasoActual];

                        final confirmacion = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: Text(AppLocalizations.of(context)!.delete_step),
                              content: Text(AppLocalizations.of(context)!.delete_step_confirmation),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: Text(AppLocalizations.of(context)!.cancel),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: Text(AppLocalizations.of(context)!.delete),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmacion != true) return;
                        await pProv.eliminarPaso(paso.numeroPaso);

                        if (!mounted) return;
                        final len = pProv.pasos.length;
                        if (len > 0) {
                          setState(() {
                            if (pasoActual >= len) pasoActual = len - 1;
                            _tituloController.text = pProv.pasos[pasoActual].titulo;
                            _descripcionController.text = pProv.pasos[pasoActual].descripcion;
                          });
                        } else {
                          setState(() {
                            _tituloController.clear();
                            _descripcionController.clear();
                          });
                        }
                      },
                      child: Text(AppLocalizations.of(context)!.delete_step),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pasos.length,
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
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(AppLocalizations.of(context)!.previous),
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: pasoActual > 0
                    ? () {
                  setState(() {
                    pasoActual--;
                    _tituloController.text = pasos[pasoActual].titulo;
                    _descripcionController.text =
                        pasos[pasoActual].descripcion;
                  });
                }
                    : null,
              ),
              ElevatedButton.icon(
                icon: Icon(
                  (pasos.isNotEmpty && pasoActual == pasos.length - 1)
                      ? Icons.check
                      : (pasos.isNotEmpty && pasoActual == pasos.length - 2)
                      ? Icons.flag
                      : Icons.arrow_forward,
                  size: 16,
                ),
                label: Text(
                  (pasos.isEmpty)
                      ? AppLocalizations.of(context)!.next
                      : (pasoActual == pasos.length - 1)
                      ? AppLocalizations.of(context)!.finish
                      : (pasoActual == pasos.length - 2)
                      ? AppLocalizations.of(context)!.finish
                      : AppLocalizations.of(context)!.next,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (pasos.isNotEmpty && pasoActual == pasos.length - 1)
                      ? Colors.green
                      : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                ),
                onPressed: (pasos.isNotEmpty && pasoActual < pasos.length - 1)
                    ? () {
                  setState(() {
                    pasoActual++;
                    _tituloController.text = pasos[pasoActual].titulo;
                    _descripcionController.text =
                        pasos[pasoActual].descripcion;
                  });
                }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}