const path = require('path');

const addressesPath = '../../addresses.json';

const addresses = require(path.join(__dirname, addressesPath));
const [targetEnv, requiredData] = process.argv.slice(2);

if (!addresses[targetEnv]) {
  console.error(
    `ERROR: Target environment "${targetEnv}" not found in addresses.json`
  );
  process.exit(1);
}
if (requiredData == 'Characters') {
  const targetDataMembers = address[targetEnv][requiredData]['Members'];
  const targetDataNames = address[targetEnv][requiredData]['CharacterNames'];
  const targetDataUris = address[targetEnv][requiredData]['SheetUris'];
  console.log('TARGET DATA Member addresses: ', targetDataMembers);
  console.log('TARGET DATA Character Names: ', targetDataNames);
  console.log('TARGET DATA URIs: ', targetDataUris);
}

const address = addresses[targetEnv][contract];

console.log(address ?? '');
