#!/usr/bin/env node
// NookDesk: 读取 posts.ts 并输出 JSON
import { createRequire } from 'module';
import { readFileSync } from 'fs';
import { execSync } from 'child_process';
import { tmpdir } from 'os';
import { join } from 'path';
import { randomBytes } from 'crypto';

const postsFile = process.argv[2];
if (!postsFile) { console.error('Usage: node read-posts.mjs <posts.ts>'); process.exit(1); }

const tmpFile = join(tmpdir(), `nookdesk-posts-${randomBytes(4).toString('hex')}.mjs`);

try {
    // 用 esbuild 转译 TypeScript → JavaScript
    execSync(`npx esbuild "${postsFile}" --bundle --format=esm --outfile="${tmpFile}"`, { 
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 15000 
    });
    
    // 动态导入转译后的模块
    const { posts } = await import(tmpFile);
    
    // 输出 JSON
    console.log(JSON.stringify(posts));
} catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
} finally {
    try { 
        const fs = await import('fs');
        fs.unlinkSync(tmpFile); 
    } catch {}
}
