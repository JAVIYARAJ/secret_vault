import 'dart:ui';
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

  Widget _buildTypeSelection(AppColors colors, bool isDark) {
    return Container(
      width: 580,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accent, colors.accent.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: colors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.category_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Secret Type',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose a template to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
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

  Widget _buildForm(AppColors colors, bool isDark) {
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 10,
            ),
            // Basic Details
            TextFormField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              decoration: inputDecoration.copyWith(
                labelText: 'Secret Title',
                hintText: 'e.g. Production Database',
                prefixIcon: const Icon(Icons.title_rounded, size: 22),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 32),
            
            Text(
              'SECRET FIELDS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  ..._fields.asMap().entries.map((entry) {
                    final index = entry.key;
                    final field = entry.value;
                    final isCustom = _selectedType == SecretType.custom;
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == _fields.length - 1 ? 0 : 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: isCustom
                                ? TextFormField(
                                    initialValue: field.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'Field Label',
                                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                                    ),
                                    onChanged: (val) {
                                      final idx = _fields.indexWhere((f) => f.id == field.id);
                                      if (idx != -1) _fields[idx] = _fields[idx].copyWith(label: val);
                                    },
                                    validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                                  )
                                : TextFormField(
                                    controller: _fieldControllers[field.id],
                                    obscureText: _obscureTextMap[field.id] ?? false,
                                    maxLines: field.isMultiline && !(_obscureTextMap[field.id] ?? false) ? 3 : 1,
                                    style: field.isSecret ? const TextStyle(letterSpacing: 2.0, fontWeight: FontWeight.w600) : const TextStyle(fontWeight: FontWeight.w500),
                                    decoration: inputDecoration.copyWith(
                                      labelText: field.label,
                                      prefixIcon: Icon(field.isSecret ? Icons.password_rounded : Icons.data_object_rounded, size: 18),
                                      suffixIcon: field.isSecret
                                          ? IconButton(
                                              icon: Icon((_obscureTextMap[field.id] ?? false) ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                                              onPressed: () => setState(() => _obscureTextMap[field.id] = !(_obscureTextMap[field.id] ?? false)),
                                            )
                                          : null,
                                    ),
                                    validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                                  ),
                          ),
                          if (isCustom) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: _fieldControllers[field.id],
                                obscureText: _obscureTextMap[field.id] ?? false,
                                style: (_obscureTextMap[field.id] ?? false) ? const TextStyle(letterSpacing: 2.0, fontWeight: FontWeight.w600) : const TextStyle(fontWeight: FontWeight.w500),
                                decoration: inputDecoration.copyWith(
                                  labelText: 'Value',
                                  prefixIcon: const Icon(Icons.password_rounded, size: 18),
                                  suffixIcon: IconButton(
                                    icon: Icon((_obscureTextMap[field.id] ?? false) ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _obscureTextMap[field.id] = !(_obscureTextMap[field.id] ?? false);
                                        final idx = _fields.indexWhere((f) => f.id == field.id);
                                        if (idx != -1) _fields[idx] = _fields[idx].copyWith(isSecret: _obscureTextMap[field.id] ?? false);
                                      });
                                    },
                                  ),
                                ),
                                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                                onPressed: () => _removeCustomField(field.id),
                                tooltip: 'Remove Field',
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  if (_selectedType == SecretType.custom) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
                          backgroundColor: colors.accent.withValues(alpha: 0.05),
                        ),
                        onPressed: _addCustomField,
                        icon: Icon(Icons.add_rounded, color: colors.accent),
                        label: Text('Add Custom Field', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text(
              'ADDITIONAL INFO',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: inputDecoration.copyWith(
                labelText: 'Note (Optional)', 
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _tagsController,
              decoration: inputDecoration.copyWith(
                labelText: 'Tags (comma separated)',
                hintText: 'e.g. work, prod, server',
                prefixIcon: const Icon(Icons.sell_outlined, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.secretToEdit != null;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 640,
            constraints: const BoxConstraints(maxHeight: 850),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? colors.card.withValues(alpha: 0.95) : const Color(0xFFFFFFFF).withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : colors.border, width: 1.5),
              boxShadow: [
                 BoxShadow(
                   color: colors.accent.withValues(alpha: 0.08),
                   blurRadius: 40,
                   spreadRadius: 8,
                   offset: const Offset(0, 16),
                 ),
                 BoxShadow(
                   color: Colors.black.withValues(alpha: 0.15),
                   blurRadius: 20,
                   offset: const Offset(0, 8),
                 ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                     padding: const EdgeInsets.fromLTRB(32, 24, 24, 24),
                     decoration: BoxDecoration(
                       color: isDark ? colors.surface.withValues(alpha: 0.5) : Colors.white,
                       border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5))),
                     ),
                     child: Row(
                       children: [
                         if (_currentStep == 1 && !isEditing)
                            Container(
                              margin: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() => _currentStep = 0),
                              ),
                            ),
                         if (_currentStep == 1 && isEditing)
                           Container(
                             padding: const EdgeInsets.all(10),
                             decoration: BoxDecoration(
                               color: colors.accent.withValues(alpha: 0.15),
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Icon(
                               Icons.auto_awesome_rounded ,
                               color: colors.accent,
                               size: 22,
                             ),
                           ),
                         const SizedBox(width: 16),
                         Text(
                           _currentStep == 0 ? 'Create New Secret' : (isEditing ? 'Edit Secret Details' : 'Fill Details'),
                           style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                         ),
                         const Spacer(),
                         Container(
                           decoration: BoxDecoration(
                             color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: IconButton(
                             icon: const Icon(Icons.close_rounded, size: 20),
                             onPressed: () => Navigator.of(context).pop(),
                           ),
                         ),
                       ],
                     ),
                  ),
                  // Body
                  Flexible(
                     child: Padding(
                       padding: EdgeInsets.all(_currentStep == 0 ? 0 : 32),
                       child: _currentStep == 0 ? _buildTypeSelection(colors, isDark) : _buildForm(colors, isDark),
                     ),
                   ),
                   // Footer
                   if (_currentStep == 1)
                     Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        decoration: BoxDecoration(
                          color: isDark ? colors.surface.withValues(alpha: 0.8) : const Color(0xFFFCFDFD),
                          border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.5))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
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
                              icon: Icon(isEditing ? Icons.check_circle_rounded : Icons.add_circle_rounded, size: 20),
                              label: Text(
                                isEditing ? 'Save Changes' : 'Add Securely',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: colors.accent,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                     )
                ],
              ),
            ),
          ),
        ),
      ),
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCirc,
          transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
          decoration: BoxDecoration(
            color: widget.isDark ? widget.colors.surface : Colors.white,
            gradient: _isHovered
                ? LinearGradient(
                    colors: [
                      widget.isDark ? widget.colors.surface : Colors.white,
                      widget.color.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.5) : widget.colors.border,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.all(_isHovered ? 16 : 14),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: _isHovered ? 32 : 28,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.type.name[0].toUpperCase() + widget.type.name.substring(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _isHovered ? FontWeight.w800 : FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
