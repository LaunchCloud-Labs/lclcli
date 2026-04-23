<?php
/**
 * LaunchCore Bootstrap Setup Script
 * ===================================
 * Visit this URL ONCE to initialize the server environment.
 * DELETE this file immediately after setup is confirmed.
 *
 * URL: https://launchcloudlabs.com/lclcli/setup.php
 */

header('Content-Type: text/html; charset=utf-8');

$root = '/home/Gcolonna/public_html/lclcli';
$secret = $_GET['secret'] ?? '';

// Protect with a simple secret to prevent unauthorized access
if ($secret !== 'launch2025') {
    http_response_code(403);
    die('<h1>403 Forbidden</h1><p>Provide ?secret=... to run setup.</p>');
}

function run_cmd($cmd) {
    return shell_exec("$cmd 2>&1") ?: '(no output)';
}

// Detect Ruby path
$ruby_paths = [
    '/usr/local/bin/ruby',
    '/opt/alt/ruby33/usr/bin/ruby',
    '/opt/alt/ruby32/usr/bin/ruby',
    '/opt/alt/ruby31/usr/bin/ruby',
    '/usr/bin/ruby',
];
$ruby = '';
foreach ($ruby_paths as $path) {
    if (file_exists($path)) { $ruby = $path; break; }
}
if (!$ruby) $ruby = trim(run_cmd('which ruby'));

// Detect Bundler
$bundle_paths = [
    '/usr/local/bin/bundle',
    '/opt/alt/ruby33/usr/bin/bundle',
    '/opt/alt/ruby32/usr/bin/bundle',
    '/usr/bin/bundle',
];
$bundle = '';
foreach ($bundle_paths as $path) {
    if (file_exists($path)) { $bundle = $path; break; }
}
if (!$bundle) $bundle = trim(run_cmd('which bundle'));

?>
<!DOCTYPE html>
<html>
<head>
  <title>LaunchCore Bootstrap</title>
  <style>
    body { font-family: monospace; background:#0d0d1a; color:#00FF41; padding:2rem; }
    h1 { color:#7B2FBE; }
    h2 { color:#FFBF00; border-bottom:1px solid #333; }
    pre { background:#111; border:1px solid #333; padding:1rem; overflow-x:auto; white-space:pre-wrap; }
    .ok  { color:#00FF41; }
    .err { color:#FF3131; }
    .warn{ color:#FFBF00; }
    .box { border:1px solid #7B2FBE; padding:1rem; margin:1rem 0; }
  </style>
</head>
<body>
<h1>⚡ LaunchCore — Server Bootstrap</h1>
<div class="box">
  <strong>Root:</strong> <?= $root ?><br>
  <strong>Ruby:</strong> <span class="<?= $ruby ? 'ok' : 'err' ?>"><?= htmlspecialchars($ruby ?: 'NOT FOUND') ?></span><br>
  <strong>Bundler:</strong> <span class="<?= $bundle ? 'ok' : 'err' ?>"><?= htmlspecialchars($bundle ?: 'NOT FOUND') ?></span>
</div>

<h2>1. Ruby Version</h2>
<pre><?= htmlspecialchars(run_cmd("$ruby --version")) ?></pre>

<h2>2. Bundle Install</h2>
<pre><?= htmlspecialchars(run_cmd("cd $root && $bundle install --path vendor/bundle --jobs 4")) ?></pre>

<h2>3. Database Initialization</h2>
<pre><?php
  $schema = file_get_contents("$root/db/schema.sql");
  $result = run_cmd("cd $root && $ruby -e \"
require 'sqlite3'
FileUtils.mkdir_p('data')
db = SQLite3::Database.new('data/launchcore.db')
sql = File.read('db/schema.sql')
sql.split(';').each { |s| db.execute(s.strip) rescue nil }
puts 'Database initialized successfully'
\"");
  echo htmlspecialchars($result);
?></pre>

<h2>4. Generate RS256 JWT Keys</h2>
<pre><?= htmlspecialchars(run_cmd("cd $root && $ruby -e \"
require_relative 'lib/launchcore'
LaunchCore::Auth::JWTManager.generate_keys!
puts 'RS256 keys generated'
\"")) ?></pre>

<h2>5. exe/lc Permissions</h2>
<pre><?= htmlspecialchars(run_cmd("chmod +x $root/exe/lc && echo 'lc binary is executable'")) ?></pre>

<h2>6. Smoke Test — lc --version</h2>
<pre><?= htmlspecialchars(run_cmd("cd $root && LCL_ROOT=$root $ruby $root/exe/lc --version")) ?></pre>

<h2>✅ Setup Complete</h2>
<p class="warn">⚠️  <strong>DELETE this file immediately:</strong> <code>rm <?= $root ?>/setup.php</code></p>
<p>Access the LaunchCore web interface at:
  <a href="/lclcli/" style="color:#00FF41">https://launchcloudlabs.com/lclcli/</a>
</p>

</body>
</html>
