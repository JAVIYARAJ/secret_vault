import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/secret.dart';
import '../services/encryption_service.dart';
import '../theme/app_theme.dart';

class AddSecretDialog extends StatefulWidget {
  final Secret? secretToEdit;

  const AddSecretDialog({super.key, this.secretToEdit});

  @override
  State<AddSecretDialog> createState() => _AddSecretDialogState();
}

class _AddSecretDialogState extends State<AddSecretDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();
  
  SecretType? _selectedType;
  List<SecretField> _fields = [];
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, bool> _obscureTextMap = {};
  
  int _currentStep = 0; 
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    if (widget.secretToEdit != null) {
      _currentStep = 1;
      _selectedType = widget.secretToEdit!.type;
      _titleController.text = widget.secretToEdit!.title;
      _noteController.text = widget.secretToEdit!.note ?? '';
      if (widget.secretToEdit!.tags != null && widget.secretToEdit!.tags!.isNotEmpty) {
        _tagsController.text = widget.secretToEdit!.tags!.join(', ');
      }
      
      final encryptionService = context.read<EncryptionService>();
      for (var f in widget.secretToEdit!.fields) {
        String decrypted = '';
        try {
          decrypted = encryptionService.decryptValue(f.encryptedValue);
        } catch (_) {}
        final fieldCopy = f.copyWith(encryptedValue: decrypted);
        _fields.add(fieldCopy);
        _fieldControllers[f.id] = TextEditingController(text: decrypted);
        _obscureTextMap[f.id] = f.isSecret;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    for (var c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTypeSelected(SecretType type) {
    setState(() {
      _selectedType = type;
      _fields = SecretTemplates.getTemplate(type);
      for (var f in _fields) {
        _fieldControllers[f.id] = TextEditingController();
        _obscureTextMap[f.id] = f.isSecret;
      }
      _currentStep = 1;
    });
  }

  void _addCustomField() {
    final id = _uuid.v4();
    final newField = SecretField(
      id: id,
      label: 'New Field',
      encryptedValue: '',
      isSecret: false,
    );
    setState(() {
      _fields.add(newField);
      _fieldControllers[id] = TextEditingController();
      _obscureTextMap[id] = false;
    });
  }

  void _removeCustomField(String id) {
    setState(() {
      _fields.removeWhere((f) => f.id == id);
      _fieldControllers[id]?.dispose();
      _fieldControllers.remove(id);
      _obscureTextMap.remove(id);
    });
  }

  IconData _getIconForType(SecretType type) {
    switch (type) {
      case SecretType.login: return Icons.login;
      case SecretType.apiKey: return Icons.vpn_key;
      case SecretType.database: return Icons.storage;
      case SecretType.sshKey: return Icons.terminal;
      case SecretType.creditCard: return Icons.credit_card;
      case SecretType.wifi: return Icons.wifi;
      case SecretType.note: return Icons.notes;
      case SecretType.custom: return Icons.build;
    }
  }

  Color _colorForType(SecretType type) {
    switch (type) {
      case SecretType.login: return const Color(0xFF4CAF50);
      case SecretType.apiKey: return const Color(0xFFFF9800);
      case SecretType.database: return const Color(0xFF2196F3);
      case SecretType.sshKey: return const Color(0xFF9C27B0);
      case SecretType.creditCard: return const Color(0xFFE91E63);
      case SecretType.wifi: return const Color(0xFF00BCD4);
      case SecretType.note: return const Color(0xFF8BC34A);
      case SecretType.custom: return const Color(0xFF607D8B);
    }
  }

  Widget _buildTypeSelection() {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 580,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.category_outlined, color: colors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Select Secret Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: SecretType.values.length,
              itemBuilder: (context, index) {
                final type = SecretType.values[index];
                final typeColor = _colorForType(type);
                return _TypeCard(
                  type: type,
                  icon: _getIconForType(type),
                  color: typeColor,
                  onTap: () => _onTypeSelected(type),
                  colors: colors,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SizedBox(
      width: 500,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Secret Title',
                  filled: true,
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ..._fields.map((field) {
                final isCustom = _selectedType == SecretType.custom;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: isCustom
                            ? TextFormField(
                                initialValue: field.label,
                                decoration: const InputDecoration(
                                  labelText: 'Field Label',
                                  filled: true,
                                ),
                                onChanged: (val) {
                                  final idx = _fields.indexWhere((f) => f.id == field.id);
                                  if (idx != -1) {
                                    _fields[idx] = _fields[idx].copyWith(label: val);
                                  }
                                },
                                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                              )
                            : TextFormField(
                                controller: _fieldControllers[field.id],
                                obscureText: _obscureTextMap[field.id] ?? false,
                                maxLines: field.isMultiline && !(_obscureTextMap[field.id] ?? false) ? 3 : 1,
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  filled: true,
                                  suffixIcon: field.isSecret
                                      ? IconButton(
                                          icon: Icon((_obscureTextMap[field.id] ?? false)
                                              ? Icons.visibility_off
                                              : Icons.visibility),
                                          onPressed: () {
                                            setState(() {
                                              _obscureTextMap[field.id] = !(_obscureTextMap[field.id] ?? false);
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                              ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _fieldControllers[field.id],
                            obscureText: _obscureTextMap[field.id] ?? false,
                            decoration: InputDecoration(
                              labelText: 'Value',
                              filled: true,
                              suffixIcon: IconButton(
                                icon: Icon((_obscureTextMap[field.id] ?? false)
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    _obscureTextMap[field.id] = !(_obscureTextMap[field.id] ?? false);
                                    final idx = _fields.indexWhere((f) => f.id == field.id);
                                    if (idx != -1) {
                                      _fields[idx] = _fields[idx].copyWith(isSecret: _obscureTextMap[field.id] ?? false);
                                    }
                                  });
                                },
                              ),
                            ),
                            validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeCustomField(field.id),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (_selectedType == SecretType.custom)
                TextButton.icon(
                  onPressed: _addCustomField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Field'),
                ),
              const Divider(),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (Optional)', filled: true),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma separated)', filled: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) {
      return AlertDialog(
        content: _buildTypeSelection(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          )
        ],
      );
    }

    final isEditing = widget.secretToEdit != null;
    return AlertDialog(
      title: Row(
        children: [
          if (!isEditing)
             IconButton(
               icon: const Icon(Icons.arrow_back),
               onPressed: () {
                 setState(() => _currentStep = 0);
               },
             ),
          Text(isEditing ? 'Edit Secret' : 'Fill Secret Details'),
        ],
      ),
      content: _buildForm(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              List<String>? tags;
              if (_tagsController.text.isNotEmpty) {
                tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              }
              
              final finalFields = _fields.map((f) => f.copyWith(
                encryptedValue: _fieldControllers[f.id]?.text ?? '',
              )).toList();

              Navigator.of(context).pop({
                'title': _titleController.text,
                'type': _selectedType,
                'fields': finalFields,
                'note': _noteController.text.isNotEmpty ? _noteController.text : null,
                'tags': tags,
              });
            }
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _TypeCard extends StatefulWidget {
  final SecretType type;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final AppColors colors;
  final bool isDark;

  const _TypeCard({
    required this.type,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: widget.isDark ? widget.colors.card : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.color : widget.colors.border,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.type.name[0].toUpperCase() + widget.type.name.substring(1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
