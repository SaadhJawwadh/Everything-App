import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import '../core/services/app_haptics.dart';

class CalculatorDialog extends StatefulWidget {
  final double? initialValue;

  const CalculatorDialog({super.key, this.initialValue});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _expression = '';
  String _history = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue != 0) {
      _expression = widget.initialValue.toString();
      // Remove trailing .0 if present
      if (_expression.endsWith('.0')) {
        _expression = _expression.substring(0, _expression.length - 2);
      }
    }
  }

  void _onPressed(String text) {
    AppHaptics.selectionClick();
    setState(() {
      if (text == 'C') {
        _expression = '';
        _history = '';
      } else if (text == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (text == '=') {
        try {
          Parser p = Parser();
          Expression exp = p.parse(_expression.replaceAll('x', '*'));
          ContextModel cm = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, cm);
          _history = _expression;
          if (eval.isNaN || eval.isInfinite) {
            _expression = 'Error';
          } else {
            _expression = eval.toString();
            if (_expression.endsWith('.0')) {
              _expression = _expression.substring(0, _expression.length - 2);
            }
          }
        } catch (e) {
          _history = _expression;
          _expression = 'Error';
        }
      } else {
        if (_expression == 'Error') {
          _expression = '';
        }
        _expression += text;
      }
    });
  }

  void _onSubmit() {
    AppHaptics.mediumImpact();
    if (_expression.isEmpty || _expression == 'Error') {
      Navigator.pop(context);
      return;
    }
    // Try to evaluate one last time if it's an expression
    try {
      Parser p = Parser();
      Expression exp = p.parse(_expression.replaceAll('x', '*'));
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      if (eval.isNaN || eval.isInfinite) {
        Navigator.pop(context);
        return;
      }
      Navigator.pop(context, eval);
    } catch (e) {
      // If parse fails, try parsing as direct double
      double? val = double.tryParse(_expression);
      if (val != null && !val.isNaN && !val.isInfinite) {
        Navigator.pop(context, val);
      } else {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildButton(String text, {IconData? icon, Color? textColor, Color? bgColor}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: Material(
          color: bgColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: const CircleBorder(), // Circular buttons for M3 look
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _onPressed(text),
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 22,
                      color: textColor ?? Theme.of(context).colorScheme.onSurface,
                    )
                  : Text(
                      text,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor ?? Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _history,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    _expression.isEmpty ? '0' : _expression,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          // Buttons
          SizedBox(
            height: 320,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('C',
                          textColor: colorScheme.error,
                          bgColor: colorScheme.errorContainer),
                      _buildButton('('),
                      _buildButton(')'),
                      _buildButton('/',
                          textColor: colorScheme.tertiary,
                          bgColor: colorScheme.tertiaryContainer),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('x',
                          textColor: colorScheme.tertiary,
                          bgColor: colorScheme.tertiaryContainer),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('-',
                          textColor: colorScheme.tertiary,
                          bgColor: colorScheme.tertiaryContainer),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('+',
                          textColor: colorScheme.tertiary,
                          bgColor: colorScheme.tertiaryContainer),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('.'),
                      _buildButton('0'),
                      _buildButton('⌫', icon: Icons.backspace_outlined),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          child: Material(
                            color: colorScheme.primary,
                            shape:
                                const StadiumBorder(), // Pill shape for equals
                            child: InkWell(
                              onTap: _onPressedOrSubmit, // Custom handler logic
                              child: Center(
                                child: Text(
                                  '=',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _onSubmit,
                icon: const Icon(Icons.check),
                label: const Text('Use Value'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onPressedOrSubmit() {
    if (_expression.contains(RegExp(r'[+\-x/]'))) {
      _onPressed('=');
    } else {
      _onSubmit();
    }
  }
}
