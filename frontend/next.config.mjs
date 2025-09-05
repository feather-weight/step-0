/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  experimental: { typedRoutes: true },
  sassOptions: {
    includePaths: ['styles', 'styles/utils']
  }
};
export default nextConfig;
