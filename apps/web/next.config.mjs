/** @type {import('next').NextConfig} */
const nextConfig = {
  // Dev lokal: teruskan /v1/* ke API agar vote real bisa diuji.
  // Produksi tidak kena (Caddy mencegat /v1/* sebelum Next).
  async rewrites() {
    return [
      {
        source: '/v1/:path*',
        destination: 'http://localhost:4301/v1/:path*',
      },
    ];
  },
};
export default nextConfig;
