const path = require("path");

const addressesPath = "../../addresses.json";

const addresses = require(path.join(__dirname, addressesPath));
const [targetEnv] = process.argv.slice(2);
if (!addresses[targetEnv]) {
  console.error(
    `ERROR: Target environment "${targetEnv}" not found in addresses.json`
  );
  process.exit(1);
}

const chainId = addresses[targetEnv].chainId;

if (!chainId) {
  console.error(
    `ERROR: "chainId" parameter not found under "${targetEnv}" target environment in addresses.json`
  );
  process.exit(1);
}

console.log(chainId);