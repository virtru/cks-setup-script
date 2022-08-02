const fs = require('fs');

// 0 = Node Path
// 1 = File Path
// 2 = Path to the Env File
// 3+ = Environment Vars to Set/Replace
const [,, envFile, ...envVariables] = process.argv;

let contents;

try {
  contents = fs.readFileSync(envFile).toString();
} catch (err) {
  console.error(err);

  process.exit(-1);
}

const lines = contents.split("\n");

const env = {};

// Set the existing Env Variables
for (const line of lines) {
  if (line.length === 0) {
    continue
  }

  const [variable, value] = line.split('=');

  env[variable] = value;
}

// Update Env Variables (replaces existing values)
for (const envVariable of envVariables) {
  const [variable, value] = envVariable.split('=');

  env[variable] = value;
}

let finalEnv = "";

for (const key in env) {
  finalEnv += `${key}=${env[key]}\n`;
}

finalEnv = finalEnv.trim();

try {
  fs.writeFileSync(envFile, finalEnv);
} catch (err) {
  console.error(err);

  process.exit(-1);
}
