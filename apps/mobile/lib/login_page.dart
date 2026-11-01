// Masuk ke SABA ala mock Stitch. Murni UI: backend auth ikut #14,
// semua aksi masuk/daftar/sosmed menjawab snackbar jujur.
import 'package:flutter/material.dart';

import 'vote.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _showPass = false;
  bool _remember = false;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what butuh backend auth (#14)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Masuk Ke Saba',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: sabaBlue,
                child: Icon(Icons.person_outline,
                    size: 16, color: Colors.white),
              ),
            ),
          ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFFE4E6EB),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('S',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: sabaBlue)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFE7F3FF),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('DISKUSI • OPINI • ESAI',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sabaBlue)),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('SABA',
                style:
                    TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          ),
          const Center(
            child: Text('Ruang Dialog & Komunitas\nPengetahuan Terverifikasi',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF65676B))),
          ),
          const SizedBox(height: 16),
          const Text('Email atau Nama',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _id,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'contoh@saba.id atau @nama',
              prefixIcon: Icon(Icons.alternate_email,
                  size: 18, color: Color(0xFF65676B)),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(12))),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Kata Sandi',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => _soon('Lupa kata sandi'),
                child: const Text('Lupa Kata Sandi?',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sabaBlue)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pass,
            obscureText: !_showPass,
            decoration: InputDecoration(
              hintText: 'Masukkan kata sandi akun',
              prefixIcon: const Icon(Icons.lock_outline,
                  size: 18, color: Color(0xFF65676B)),
              suffixIcon: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                    _showPass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18),
                color: const Color(0xFF65676B),
                onPressed: () =>
                    setState(() => _showPass = !_showPass),
              ),
              border: const OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(12))),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _remember = !_remember),
            child: Row(
              children: [
                Checkbox(
                    value: _remember,
                    activeColor: sabaBlue,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) =>
                        setState(() => _remember = v ?? false)),
                const Text('Ingat saya di perangkat ini',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              // Mockup tanpa backend: langsung masuk ke halaman utama.
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Masuk ke SABA'),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFE4E6EB))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('ATAU MASUK DENGAN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF65676B))),
              ),
              Expanded(child: Divider(color: Color(0xFFE4E6EB))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE4E6EB),
                  foregroundColor: const Color(0xFF050505),
                ),
                onPressed: () => _soon('Lanjut dengan Google'),
                child: const Text('Lanjutkan dengan Google')),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE4E6EB),
                  foregroundColor: const Color(0xFF050505),
                ),
                onPressed: () => _soon('Lanjut dengan Apple'),
                child: const Text('Lanjutkan dengan Apple')),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFE7F3FF),
                borderRadius: BorderRadius.circular(12)),
            child: const Text(
                'Intelektualitas Kolaboratif. Diskusi santun berbasis referensi terpercaya. Bergabunglah dengan puluhan ribu pemikir independen.',
                style: TextStyle(fontSize: 12, height: 1.5)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Belum punya akun SABA? ',
                  style: TextStyle(fontSize: 12)),
              GestureDetector(
                onTap: () => _soon('Daftar'),
                child: const Text('Daftar Sekarang',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: sabaBlue)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
