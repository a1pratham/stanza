import 'package:flutter/material.dart';
import '../../models/profile.dart';
import '../../models/topic.dart';
import '../../services/profile_service.dart';

/// Two-step onboarding: (1) choose interests, (2) language / morning
/// brief / notifications. Saves after each step, so closing the app
/// partway and reopening resumes with earlier answers already stored:
/// if interests were saved, it reopens straight on step 2.
///
/// AppRoot constructs this and decides when onboarding is over;
/// [onCompleted] is called only after everything has been saved.
class OnboardingScreen extends StatefulWidget {
  final String uid;
  final ProfileService profileService;
  final Future<void> Function() onCompleted;

  const OnboardingScreen({
    super.key,
    required this.uid,
    required this.profileService,
    required this.onCompleted,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0 = interests, 1 = preferences
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;

  List<TopicGroup> _groups = const [];
  Set<String> _selected = {};

  bool _morningEnabled = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);
  bool _breakingNews = true;
  bool _recommended = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final groups = await widget.profileService.fetchTopicTaxonomy();
      final selected = await widget.profileService.fetchSelectedInterestIds(widget.uid);
      final prefs = await widget.profileService.fetchPreferences(widget.uid);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selected = selected;
        _applyPreferences(prefs);
        // Interests already saved => this is a resume; skip ahead.
        _step = selected.isNotEmpty ? 1 : 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = "Couldn't load your setup. Check your connection and try again.";
        _loading = false;
      });
    }
  }

  void _applyPreferences(ProfilePreferences prefs) {
    _morningEnabled = prefs.morningBriefEnabled;
    _breakingNews = prefs.breakingNewsEnabled;
    _recommended = prefs.recommendedStoriesEnabled;
    final parts = prefs.morningBriefTime.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) _morningTime = TimeOfDay(hour: h, minute: m);
    }
  }

  String get _morningTimeString =>
      '${_morningTime.hour.toString().padLeft(2, '0')}:${_morningTime.minute.toString().padLeft(2, '0')}';

  Future<void> _saveInterestsAndContinue() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.profileService.setInterests(widget.uid, _selected.toList());
      if (mounted) setState(() => _step = 1);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = "Couldn't save your interests. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.profileService.updatePreferences(
        widget.uid,
        language: 'en',
        morningBriefEnabled: _morningEnabled,
        morningBriefTime: _morningTimeString,
        breakingNewsEnabled: _breakingNews,
        recommendedStoriesEnabled: _recommended,
      );
      // Last, so a failure above never leaves someone marked complete
      // with unsaved preferences.
      await widget.profileService.markOnboardingComplete(widget.uid);
      await widget.onCompleted();
    } catch (_) {
      if (mounted) setState(() => _saveError = "Couldn't save your settings. Please try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _morningTime);
    if (picked != null && mounted) setState(() => _morningTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const Text('Stanza',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_step + 1}/2', style: const TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LinearProgressIndicator(value: (_step + 1) / 2),
            ),
            Expanded(child: _step == 0 ? _buildInterests() : _buildPreferences()),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(_saveError!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_step == 1)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step = 0),
                      child: const Text('Back'),
                    ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : _step == 0
                              ? (_selected.isNotEmpty ? _saveInterestsAndContinue : null)
                              : _finish,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_step == 0 ? 'Continue' : 'Get started'),
                      ),
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

  Widget _buildInterests() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        const Text('Choose your interests',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Select at least one topic to personalise your news experience.',
            style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 16),
        for (final group in _groups)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  if (group.description != null)
                    Text(group.description!, style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in group.topics)
                        FilterChip(
                          label: Text(topic.name),
                          selected: _selected.contains(topic.topicId),
                          onSelected: _saving
                              ? null
                              : (on) => setState(() {
                                    _selected = on
                                        ? {..._selected, topic.topicId}
                                        : ({..._selected}..remove(topic.topicId));
                                  }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreferences() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        const Text('Almost there.',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('A few final choices, and your Stanza is ready.',
            style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 24),
        const Text('LANGUAGE', style: TextStyle(color: Colors.white54, letterSpacing: 1.5)),
        const Card(
          child: ListTile(
            leading: Icon(Icons.language),
            title: Text('English'),
            subtitle: Text('More languages coming later.'),
          ),
        ),
        const SizedBox(height: 16),
        const Text('YOUR DAILY BRIEF',
            style: TextStyle(color: Colors.white54, letterSpacing: 1.5)),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.access_time),
                title: const Text('Morning Brief'),
                subtitle: const Text("A quick overview of what's happening when you start your day."),
                value: _morningEnabled,
                onChanged: _saving ? null : (v) => setState(() => _morningEnabled = v),
              ),
              ListTile(
                enabled: _morningEnabled && !_saving,
                title: const Text('Time'),
                trailing: Text(_morningTime.format(context)),
                onTap: (_morningEnabled && !_saving) ? _pickTime : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('NOTIFICATIONS', style: TextStyle(color: Colors.white54, letterSpacing: 1.5)),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_none),
                title: const Text('Breaking news'),
                subtitle: const Text('Important stories as they happen.'),
                value: _breakingNews,
                onChanged: _saving ? null : (v) => setState(() => _breakingNews = v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Recommended stories'),
                subtitle: const Text('Stories picked for your interests.'),
                value: _recommended,
                onChanged: _saving ? null : (v) => setState(() => _recommended = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
