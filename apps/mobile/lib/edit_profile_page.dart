// Edit Profile per Stitch mockup. State stored locally (ProfileStore);
// backend + real photo follows #14.
import 'package:flutter/material.dart';

import 'profile.dart';
import 'saba_theme.dart';
import 'vote.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _name = TextEditingController(text: ProfileStore.name);
  late final _headline =
      TextEditingController(text: ProfileStore.headline);
  late final _about = TextEditingController(text: ProfileStore.about);
  late final _location =
      TextEditingController(text: ProfileStore.location);
  late final _website = TextEditingController(text: ProfileStore.website);
  late final List<String> _topics = [...ProfileStore.topics];
  late bool _badge = ProfileStore.showBadge;
  late bool _dm = ProfileStore.allowDm;
  late bool _activity = ProfileStore.showActivity;

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    _about.dispose();
    _location.dispose();
    _website.dispose();
    super.dispose();
  }

  void _save() {
    ProfileStore.name = _name.text.trim();
    ProfileStore.headline = _headline.text.trim();
    ProfileStore.about = _about.text.trim();
    ProfileStore.location = _location.text.trim();
    ProfileStore.website = _website.text.trim();
    ProfileStore.topics = [..._topics];
    ProfileStore.showBadge = _badge;
    ProfileStore.allowDm = _dm;
    ProfileStore.showActivity = _activity;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved on this device.')),
    );
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon (#14)')),
    );
  }

  Future<void> _addTopic() async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Topic'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '@technology',
            border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.all(Radius.circular(12))),
            isDense: true,
          ),
          onSubmitted: (_) =>
              Navigator.of(ctx).pop(ctrl.text.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    final t = (v ?? '').replaceAll('@', '').trim();
    if (t.isNotEmpty && !_topics.contains(t)) {
      setState(() => _topics.add(t));
    }
  }

  /// Mockup-style sample credential row (local demo, no backend).
  Widget _credRow(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: SabaColors.greyFill,
                borderRadius: BorderRadius.circular(8)),
            child:
                Icon(icon, size: 18, color: SabaColors.muted2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        color: SabaColors.muted2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _soon('Edit credentials'),
            child: const Icon(Icons.edit_outlined,
                size: 16, color: SabaColors.muted2),
          ),
        ],
      ),
    );
  }

  Widget _label(String s, {String? counter}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(s,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          if (counter != null) ...[
            const Spacer(),
            Text(counter,
                style: const TextStyle(
                    fontSize: 11, color: SabaColors.muted2)),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController c,
      {String? hint,
      int maxLines = 1,
      int? maxLength,
      IconData? icon,
      TextInputType? keyboard}) {
    OutlineInputBorder border(Color color, [double w = 1]) =>
        OutlineInputBorder(
            borderRadius:
                const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: color, width: w));
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboard,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontSize: 13, color: SabaColors.muted2),
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: SabaColors.muted2),
          border: border(SabaColors.borderSoft.withValues(alpha: 0)),
          enabledBorder:
              border(SabaColors.borderSoft.withValues(alpha: 0)),
          focusedBorder: border(SabaColors.primary, 1.5),
          isDense: true,
          filled: true,
          fillColor: SabaColors.greyFill,
          counterText: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isEmpty
        ? 'S'
        : _name.text.trim()[0].toUpperCase();
    return Scaffold(
      backgroundColor: SabaColors.bgWarm,
      appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Edit Profile',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20),
                  ),
                  onPressed: _save,
                  child: const Text('Save')),
            ),
          ]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: SabaColors.borderSoft)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Basic Information',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              SabaColors.chipBlueBg,
                          child: Text(initial,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: sabaBlue)),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: GestureDetector(
                            onTap: () => _soon('Change photo'),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: sabaBlue,
                              child: Icon(Icons.camera_alt,
                                  size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _soon('Change photo'),
                                child: const Text('Change Photo',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        color: sabaBlue)),
                              ),
                              const Text('  •  ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: SabaColors.muted2)),
                              GestureDetector(
                                onTap: () => _soon('Remove photo'),
                                child: const Text('Remove',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: SabaColors.muted2)),
                              ),
                            ],
                          ),
                          const Text('JPG, PNG format, 2MB max',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: SabaColors.muted2)),
                        ],
                      ),
                    ),
                  ],
                ),
                _label('Full Name'),
                _field(_name, hint: 'Full name'),
                _label('Role & Organization (Short Bio)'),
                _field(_headline,
                    hint: 'Principal Designer at SABA'),
                _label('About',
                    counter: '${_about.text.length}/240'),
                _field(_about,
                    hint: 'Tell us about yourself…',
                    maxLines: 4,
                    maxLength: 240),
                _label('Current Location'),
                _field(_location,
                    hint: 'Jakarta, Indonesia',
                    icon: Icons.location_on_outlined),
                _label('Website / Portfolio'),
                _field(_website,
                    hint: 'https://yourname.id',
                    icon: Icons.language_outlined,
                    keyboard: TextInputType.url),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: SabaColors.borderSoft)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Credentials & Affiliations',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Experience',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _soon('Add experience'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const Text('No experience yet.',
                    style: TextStyle(
                        fontSize: 12,
                        color: SabaColors.muted2)),
                _credRow(Icons.business_outlined, 'Nexus Labs',
                    'Principal Designer • 2020 — Present'),
                Row(
                  children: [
                    const Text('Education',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _soon('Add education'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const Text('No education yet.',
                    style: TextStyle(
                        fontSize: 12,
                        color: SabaColors.muted2)),
                _credRow(Icons.school_outlined,
                    'Institut Teknologi Bandung',
                    'M.Sc. Computer Science • 2018'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Topics',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${_topics.length} Selected',
                        style: const TextStyle(
                            fontSize: 11,
                            color: SabaColors.muted2)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _topics)
                      Container(
                        padding: const EdgeInsets.only(
                            left: 10, top: 4, bottom: 4, right: 4),
                        decoration: BoxDecoration(
                            color: SabaColors.chipBlueBg,
                            borderRadius:
                                BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('@$t',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: sabaBlue)),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _topics.remove(t)),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close,
                                    size: 14, color: sabaBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: _addTopic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(999),
                            border: Border.all(
                                color: sabaBlue)),
                        child: const Text('+ New Topic',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sabaBlue)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: SabaColors.borderSoft)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Privacy & Public Visibility',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                _toggle('Top Creator Badge',
                    'Show the reputation badge next to your name on the discussion feed',
                    _badge, (v) => setState(() => _badge = v)),
                _toggle('Allow Direct Messages (DM)',
                    'Let fellow community members start a chat with you',
                    _dm, (v) => setState(() => _dm = v)),
                _toggle('Public Feed Activity',
                    'Show your favorite answers & replies on the timeline tab',
                    _activity,
                    (v) => setState(() => _activity = v)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _save,
                child: const Text('Save Changes')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    child: const Text('Cancel')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    icon: const Icon(
                        Icons.visibility_outlined,
                        size: 16),
                    label: const Text('Preview')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(
      String title, String sub, bool v, ValueChanged<bool> on) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11,
                        color: SabaColors.muted2)),
              ],
            ),
          ),
          Switch(value: v, activeThumbColor: sabaBlue, onChanged: on),
        ],
      ),
    );
  }
}
