const path = require('path');
const fs = require('fs');

const addressesPath = '../../addresses.json';

let addresses = require(path.join(__dirname, addressesPath));
const [targetEnv, subPath, input] = process.argv.slice(2);

let index = 0;

if (subPath == 'Characters') {
  let splitInput = input.split(';').map((e) => e.trim());
  let newCharacter = {
    MemberAddress: splitInput[0],
    CharacterName: splitInput[1],
    uri: splitInput[2],
  };

  if (
    addresses[targetEnv][subPath].find(
      (el) => el.MemberAddress == splitInput[0]
    )
  ) {
    throw new Error('this character already exists.');
  }

  addresses[targetEnv][subPath] = [
    ...addresses[targetEnv][subPath],
    newCharacter,
  ];
} else if (subPath == 'Items') {
  const splitInput = input.split('|').map((e) => e.trim());

  if (splitInput.length < 4) {
    throw new Error('Invalid Input');
  }

  const itemProperties = splitInput[0]
    .split(';')
    .map((e) => e.trim())
    .filter((prop) => prop !== '');

  const itemRequirements =
    splitInput[1] == 'null'
      ? [[0, 0]]
      : splitInput[1]
          .split('*')
          .map((e) => e.trim().toLowerCase())
          .map((e) => e.split(':'))
          .filter((req) => req[0] !== '')
          .filter((merk) => merk !== '')
          .map((el) => {
            return [el[0], parseInt(el[1])];
          });

  const classReq = splitInput[2]
    .split(':')
    .filter((classRequirement) => classRequirement !== '')
    .filter((req) => req !== 'null');

  const itemMerkle =
    splitInput[3] == 'null'
      ? [[0, 0]]
      : splitInput[3]
          .split('*')
          .map((e) => e.trim().toLowerCase())
          .map((e) => e.split(':'))
          .filter((merk) => merk !== '')
          .map((el) => {
            return [el[0], parseInt(el[1])];
          });

  if (
    addresses[targetEnv][subPath].find((el) => el.ItemName == itemProperties[0])
  ) {
    throw new Error('this character already exists.');
  }
  let newRequirements = {
    classRequirements: classReq,
    itemRequirements: itemRequirements,
    claimable: itemMerkle,
  };
  let newItem = {
    cid: itemProperties[2],
    name: itemProperties[0],
    supply: itemProperties[1],
    soulbound: itemProperties[3] == 'true' ? true : false,
    requirements: newRequirements,
  };

  addresses[targetEnv][subPath] = [...addresses[targetEnv][subPath], newItem];
} else if (subPath == 'Classes') {
  const splitInput = input
    .split(';')
    .map((input) => input.trim().toLowerCase());

  const className = splitInput[0];
  const classBool = splitInput[1] == 'y' ? true : false;
  const classUri = splitInput[2].length == '' ? null : splitInput[1];

  const newClass = {
    ClassName: className,
    Claimable: classBool,
    ClassUri: classUri,
  };

  addresses[targetEnv][subPath] = [...addresses[targetEnv][subPath], newClass];
}

fs.writeFileSync(
  path.join(__dirname, addressesPath),
  JSON.stringify(addresses, null, 2) + '\n'
);
index =
  addresses[targetEnv][subPath].length == 0
    ? 0
    : addresses[targetEnv][subPath].length - 1;
const location = 'index: '.concat(index);
console.log('Updated `addresses.json`', location);
