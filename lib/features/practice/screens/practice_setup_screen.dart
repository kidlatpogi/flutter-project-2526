import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_names.dart';

class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  String? _selectedScriptId;
  String _selectedFocus = 'scripted';
  List<Map<String, dynamic>> _scripts = [];

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  Future<void> _loadScripts() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser == null) {
        return;
      }
      
      // Query scripts table for current user
        final response = await supabase
          .from('scripts')
          .select('id, title, content')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          // Extract script titles from response
          _scripts = List<Map<String, dynamic>>.from(response as List);
          
          // Set first script as default if available
          if (_scripts.isNotEmpty) {
            _selectedScriptId = _scripts.first['id'] as String?;
          }
        });
      }
    } catch (e) {
      // Keep empty list if error occurs
      if (mounted) {
        setState(() {
          _scripts = [];
        });
      }
    }
  }

  Future<void> _navigateToCreateScript() async {
    final result = await Navigator.pushNamed(context, RouteNames.createScript);
    // If a new script was created (result == true), reload scripts
    if (result == true && mounted) {
      _loadScripts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Practice Setup',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What are you practicing section
            Text(
              'WHAT ARE YOU PRACTICING?',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 12),

            // Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedFocus == 'free' 
                    ? AppColors.inactive.withOpacity(0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFocus == 'free'
                      ? AppColors.inactive.withOpacity(0.2)
                      : AppColors.inactive.withOpacity(0.3),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedScriptId,
                  isExpanded: true,
                  disabledHint: Text(
                    _scripts.isEmpty
                        ? 'No scripts available'
                        : (_getSelectedScriptTitle() ?? 'Select a script'),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.inactive,
                    ),
                  ),
                  hint: Text(
                    _scripts.isEmpty ? 'No scripts available' : 'Select a script',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: _selectedFocus == 'free' ? AppColors.inactive : AppColors.primary,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                  items: _scripts.isEmpty
                      ? [
                          DropdownMenuItem<String>(
                            value: 'new_script',
                            child: Text('+ Create New Script'),
                          )
                        ]
                      : [
                          ...(_scripts.map((script) {
                            return DropdownMenuItem<String>(
                              value: script['id'] as String,
                              child: Text(script['title'] ?? 'Untitled'),
                            );
                          }).toList()),
                          DropdownMenuItem<String>(
                            value: 'new_script',
                            child: Text('+ Create New Script'),
                          ),
                        ],
                  onChanged: _selectedFocus == 'free'
                      ? null
                      : (String? newValue) {
                          if (newValue == 'new_script') {
                            _navigateToCreateScript();
                          } else if (newValue != null) {
                            setState(() {
                              _selectedScriptId = newValue;
                            });
                          }
                        },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Selected from your library text or No scripts message
            if (_scripts.isEmpty)
              Text(
                'Create a script in the Scripts section to practice',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (_selectedFocus == 'free')
              Text(
                'Script selection is disabled for Free Speech mode',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                'Selected from your library',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),

            const SizedBox(height: 32),

            // Choose your focus section
            Text(
              'CHOOSE YOUR FOCUS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 12),

            // Scripted Accuracy option
            _buildFocusOption(
              value: 'scripted',
              title: 'Scripted Accuracy',
              description:
                  'Strict adherence to text for pronunciations. AI will track every word.',
            ),

            const SizedBox(height: 12),

            // Free Speech option
            _buildFocusOption(
              value: 'free',
              title: 'Free Speech',
              description:
                  'Impromptu speaking style. Focus on flow, tone, and pacing.',
            ),

            const Spacer(),

            // Start Recording button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (_selectedFocus == 'scripted' && _selectedScriptId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a script for Scripted Accuracy'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // For Free Speech, show modal to ask for speech topic
                  if (_selectedFocus == 'free') {
                    final topic = await _showFreeSpeechTopicDialog();
                    if (topic == null) return; // User cancelled
                    
                    Navigator.pushNamed(
                      context,
                      RouteNames.recording,
                      arguments: {
                        'isScripted': false,
                        'scriptTitle': topic.isNotEmpty ? topic : 'Free Speech',
                        'scriptContent': null,
                        'freeSpeechTopic': topic,
                      },
                    );
                    return;
                  }

                  final selectedScript = _findScriptById(_selectedScriptId);
                  Navigator.pushNamed(
                    context,
                    RouteNames.recording,
                    arguments: {
                      'isScripted': _selectedFocus == 'scripted',
                      'scriptTitle': selectedScript?['title'],
                      'scriptContent': selectedScript?['content'],
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mic,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Start Recording',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<String?> _showFreeSpeechTopicDialog() async {
    final topicController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'What is your speech about?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a topic to help the AI better evaluate your speech.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: topicController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., Climate Change, My Vacation...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary.withOpacity(0.6),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.text,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, topicController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Start',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findScriptById(String? id) {
    if (id == null) return null;
    for (final script in _scripts) {
      if (script['id'] == id) return script;
    }
    return null;
  }

  String? _getSelectedScriptTitle() {
    return _findScriptById(_selectedScriptId)?['title'] as String?;
  }

  Widget _buildFocusOption({
    required String value,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedFocus == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFocus = value;
          if (_selectedFocus == 'scripted' && _selectedScriptId == null && _scripts.isNotEmpty) {
            _selectedScriptId = _scripts.first['id'] as String?;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.inactive.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.inactive,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
