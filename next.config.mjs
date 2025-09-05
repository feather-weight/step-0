import path from 'path';

const nextConfig = {
  output: 'standalone',
  experimental: { typedRoutes: true },
  sassOptions: {
    includePaths: [
      path.join(process.cwd(), 'styles'),
      path.join(process.cwd(), 'styles', 'utils')
    ]
  }
};

export default nextConfig;
