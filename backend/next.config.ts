import type { NextConfig } from "next";
import { config } from "dotenv";
import path from "path";

// Load the root .env file
config({ path: path.resolve(process.cwd(), "../.env") });

const nextConfig: NextConfig = {
  /* config options here */
};

export default nextConfig;
