/* eslint-disable no-case-declarations */
import {
  CairoUint256,
  CairoUint512,
  addHexPrefix,
  encode,
  num,
  shortString,
  byteArray,
  cairo,
  CairoCustomEnum,
  CairoOption,
  CairoOptionVariant,
  CairoResult,
  CairoResultVariant,
  tu,
} from "starknet";
const { addHexPrefix, removeHexPrefix } = encode;
const { toHex } = num;
const { decodeShortString } = shortString;
const { stringFromByteArray } = byteArray;
const {
  getArrayType,
  isCairo1Type,
  isLen,
  isTypeArray,
  isTypeBool,
  isTypeByteArray,
  isTypeBytes31,
  isTypeEnum,
  isTypeEthAddress,
  isTypeNonZero,
  isTypeSecp256k1Point,
  isTypeTuple,
  isTypeNamedTuple,
} = cairo;
import {
  CairoCustomEnum,
  CairoOption,
  CairoOptionVariant,
  CairoResult,
  CairoResultVariant,
} from "./enum";
import extractTupleMemberTypes from "./tuple";

function parseNamedTuple(namedTuple) {
  const name = namedTuple.substring(0, namedTuple.indexOf(":"));
  const type = namedTuple.substring(name.length + ":".length);
  return { name, type };
}

function parseSubTuple(s) {
  if (!s.includes("(")) return { subTuple: [], result: s };
  const subTuple = [];
  let result = "";
  let i = 0;
  while (i < s.length) {
    if (s[i] === "(") {
      let counter = 1;
      const lBracket = i;
      i++;
      while (counter) {
        if (s[i] === ")") counter--;
        if (s[i] === "(") counter++;
        i++;
      }
      subTuple.push(s.substring(lBracket, i));
      result += " ";
      i--;
    } else {
      result += s[i];
    }
    i++;
  }

  return {
    subTuple,
    result,
  };
}

function extractCairo0Tuple(type) {
  const cleanType = type.replace(/\s/g, "").slice(1, -1); // remove first lvl () and spaces

  // Decompose subTuple
  const { subTuple, result } = parseSubTuple(cleanType);

  // Recompose subTuple
  let recomposed = result.split(",").map((it) => {
    return subTuple.length ? it.replace(" ", subTuple.shift()) : it;
  });

  // Parse named tuple
  if (isTypeNamedTuple(type)) {
    recomposed = recomposed.reduce((acc, it) => {
      return acc.concat(parseNamedTuple(it));
    }, []);
  }

  return recomposed;
}

function getClosureOffset(input, open, close) {
  for (let i = 0, counter = 0; i < input.length; i++) {
    if (input[i] === open) {
      counter++;
    } else if (input[i] === close && --counter === 0) {
      return i;
    }
  }
  return Number.POSITIVE_INFINITY;
}

function extractCairo1Tuple(type) {
  // un-named tuples support
  const input = type.slice(1, -1); // remove first lvl ()
  const result = [];

  let currentIndex = 0;
  let limitIndex;

  while (currentIndex < input.length) {
    switch (true) {
      // Tuple
      case input[currentIndex] === "(": {
        limitIndex =
          currentIndex +
          getClosureOffset(input.slice(currentIndex), "(", ")") +
          1;
        break;
      }
      case input.startsWith("core::result::Result::<", currentIndex) ||
        input.startsWith("core::array::Array::<", currentIndex) ||
        input.startsWith("core::option::Option::<", currentIndex): {
        limitIndex =
          currentIndex +
          getClosureOffset(input.slice(currentIndex), "<", ">") +
          1;
        break;
      }
      default: {
        const commaIndex = input.indexOf(",", currentIndex);
        limitIndex = commaIndex !== -1 ? commaIndex : Number.POSITIVE_INFINITY;
      }
    }

    result.push(input.slice(currentIndex, limitIndex));
    currentIndex = limitIndex + 2; // +2 to skip ', '
  }

  return result;
}

/**
 * Convert a tuple string definition into an object-like definition.
 * Supports both Cairo 0 and Cairo 1 tuple formats.
 *
 * @param type - The tuple string definition (e.g., "(u8, u8)" or "(x:u8, y:u8)").
 * @returns An array of strings or objects representing the tuple components.
 *
 * @example
 * // Cairo 0 Tuple
 * const cairo0Tuple = "(u8, u8)";
 * const result = extractTupleMemberTypes(cairo0Tuple);
 * // result: ["u8", "u8"]
 *
 * @example
 * // Named Cairo 0 Tuple
 * const namedCairo0Tuple = "(x:u8, y:u8)";
 * const namedResult = extractTupleMemberTypes(namedCairo0Tuple);
 * // namedResult: [{ name: "x", type: "u8" }, { name: "y", type: "u8" }]
 *
 * @example
 * // Cairo 1 Tuple
 * const cairo1Tuple = "(core::result::Result::<u8, u8>, u8)";
 * const cairo1Result = extractTupleMemberTypes(cairo1Tuple);
 * // cairo1Result: ["core::result::Result::<u8, u8>", "u8"]
 */
export default function extractTupleMemberTypes(type) {
  return isCairo1Type(type)
    ? extractCairo1Tuple(type)
    : extractCairo0Tuple(type);
}

/**
 * Parse base types
 * @param type type of element
 * @param it iterator
 * @returns bigint | boolean
 */
function parseBaseTypes(type, it) {
  let temp;
  switch (true) {
    case isTypeBool(type):
      temp = it.next().value;
      return Boolean(BigInt(temp));
    case CairoUint256.isAbiType(type):
      const low = it.next().value;
      const high = it.next().value;
      return new CairoUint256(low, high).toBigInt();
    case CairoUint512.isAbiType(type):
      const limb0 = it.next().value;
      const limb1 = it.next().value;
      const limb2 = it.next().value;
      const limb3 = it.next().value;
      return new CairoUint512(limb0, limb1, limb2, limb3).toBigInt();
    case isTypeEthAddress(type):
      temp = it.next().value;
      return BigInt(temp);
    case isTypeBytes31(type):
      temp = it.next().value;
      return decodeShortString(temp);
    case isTypeSecp256k1Point(type):
      const xLow = removeHexPrefix(it.next().value).padStart(32, "0");
      const xHigh = removeHexPrefix(it.next().value).padStart(32, "0");
      const yLow = removeHexPrefix(it.next().value).padStart(32, "0");
      const yHigh = removeHexPrefix(it.next().value).padStart(32, "0");
      const pubK = BigInt(addHexPrefix(xHigh + xLow + yHigh + yLow));
      return pubK;
    default:
      temp = it.next().value;
      return BigInt(temp);
  }
}

/**
 * Parse of the response elements that are converted to Object (Struct) by using the abi
 *
 * @param responseIterator - iterator of the response
 * @param element - element of the field {name: string, type: string}
 * @param structs - structs from abi
 * @param enums
 * @return {any} - parsed arguments in format that contract is expecting
 */
const parseResponseValue = (responseIterator, element, structs, enums) => {
  if (element.type === "()") {
    return {};
  }
  // type uint256 struct (c1v2)
  if (CairoUint256.isAbiType(element.type)) {
    const low = responseIterator.next().value;
    const high = responseIterator.next().value;
    return new CairoUint256(low, high).toBigInt();
  }
  // type uint512 struct
  if (CairoUint512.isAbiType(element.type)) {
    const limb0 = responseIterator.next().value;
    const limb1 = responseIterator.next().value;
    const limb2 = responseIterator.next().value;
    const limb3 = responseIterator.next().value;
    return new CairoUint512(limb0, limb1, limb2, limb3).toBigInt();
  }
  // type C1 ByteArray struct, representing a LongString
  if (isTypeByteArray(element.type)) {
    const parsedBytes31Arr = [];
    const bytes31ArrLen = BigInt(responseIterator.next().value);
    while (parsedBytes31Arr.length < bytes31ArrLen) {
      parsedBytes31Arr.push(toHex(responseIterator.next().value));
    }
    const pending_word = toHex(responseIterator.next().value);
    const pending_word_len = BigInt(responseIterator.next().value);
    const myByteArray = {
      data: parsedBytes31Arr,
      pending_word,
      pending_word_len,
    };
    return stringFromByteArray(myByteArray);
  }

  // type fixed-array
  if (CairoFixedArray.isTypeFixedArray(element.type)) {
    const parsedDataArr = [];
    const el = {
      name: "",
      type: CairoFixedArray.getFixedArrayType(element.type),
    };
    const arraySize = CairoFixedArray.getFixedArraySize(element.type);
    while (parsedDataArr.length < arraySize) {
      parsedDataArr.push(
        parseResponseValue(responseIterator, el, structs, enums)
      );
    }
    return parsedDataArr;
  }

  // type c1 array
  if (isTypeArray(element.type)) {
    // eslint-disable-next-line no-case-declarations
    const parsedDataArr = [];
    const el = { name: "", type: getArrayType(element.type) };
    const len = BigInt(responseIterator.next().value); // get length
    while (parsedDataArr.length < len) {
      parsedDataArr.push(
        parseResponseValue(responseIterator, el, structs, enums)
      );
    }
    return parsedDataArr;
  }

  // type NonZero
  if (isTypeNonZero(element.type)) {
    // eslint-disable-next-line no-case-declarations
    // const parsedDataArr: (BigNumberish | ParsedStruct | boolean | any[] | CairoEnum)[] = [];
    const el = { name: "", type: getArrayType(element.type) };
    // parsedDataArr.push();
    return parseResponseValue(responseIterator, el, structs, enums);
  }

  // type struct
  if (structs && element.type in structs && structs[element.type]) {
    if (isTypeEthAddress(element.type)) {
      return parseBaseTypes(element.type, responseIterator);
    }
    return structs[element.type].members.reduce((acc, el) => {
      acc[el.name] = parseResponseValue(responseIterator, el, structs, enums);
      return acc;
    }, {});
  }

  // type Enum (only CustomEnum)
  if (enums && element.type in enums && enums[element.type]) {
    const variantNum = Number(responseIterator.next().value); // get variant number
    const rawEnum = enums[element.type].variants.reduce((acc, variant, num) => {
      if (num === variantNum) {
        acc[variant.name] = parseResponseValue(
          responseIterator,
          { name: "", type: variant.type },
          structs,
          enums
        );
        return acc;
      }
      acc[variant.name] = undefined;
      return acc;
    }, {});
    // Option
    if (element.type.startsWith("core::option::Option")) {
      const content =
        variantNum === CairoOptionVariant.Some ? rawEnum.Some : undefined;
      return new CairoOption() < Object > (variantNum, content);
    }
    // Result
    if (element.type.startsWith("core::result::Result")) {
      let content;
      if (variantNum === CairoResultVariant.Ok) {
        content = rawEnum.Ok;
      } else {
        content = rawEnum.Err;
      }
      return new CairoResult() < Object, Object > (variantNum, content);
    }
    // Cairo custom Enum
    const customEnum = new CairoCustomEnum(rawEnum);
    return customEnum;
  }

  // type tuple
  if (isTypeTuple(element.type)) {
    const memberTypes = extractTupleMemberTypes(element.type);
    return memberTypes.reduce((acc, it, idx) => {
      const name = it?.name ? it.name : idx;
      const type = it?.type ? it.type : it;
      const el = { name, type };
      acc[name] = parseResponseValue(responseIterator, el, structs, enums);
      return acc;
    }, {});
  }

  // type c1 array
  if (isTypeArray(element.type)) {
    // eslint-disable-next-line no-case-declarations
    const parsedDataArr = [];
    const el = { name: "", type: getArrayType(element.type) };
    const len = BigInt(responseIterator.next().value); // get length
    while (parsedDataArr.length < len) {
      parsedDataArr.push(
        parseResponseValue(responseIterator, el, structs, enums)
      );
    }
    return parsedDataArr;
  }

  // base type
  return parseBaseTypes(element.type, responseIterator);
};

/**
 * Parse elements of the response and structuring them into one field by using output property from the abi for that method
 *
 * @param responseIterator - iterator of the response
 * @param output - output(field) information from the abi that will be used to parse the data
 * @param structs - structs from abi
 * @param parsedResult
 * @return - parsed response corresponding to the abi structure of the field
 */
export const responseParser = (
  responseIterator,
  output,
  structs,
  enums,
  parsedResult
) => {
  const { name, type } = output;
  let temp;

  switch (true) {
    case isLen(name):
      temp = responseIterator.next().value;
      return BigInt(temp);

    case (structs && type in structs) || isTypeTuple(type):
      return parseResponseValue(responseIterator, output, structs, enums);

    case enums && isTypeEnum(type, enums):
      return parseResponseValue(responseIterator, output, structs, enums);

    case CairoFixedArray.isTypeFixedArray(type):
      return parseResponseValue(responseIterator, output, structs, enums);

    case isTypeArray(type):
      // C1 Array
      if (isCairo1Type(type)) {
        return parseResponseValue(responseIterator, output, structs, enums);
      }
      // C0 Array
      // eslint-disable-next-line no-case-declarations
      const parsedDataArr = [];
      if (parsedResult && parsedResult[`${name}_len`]) {
        const arrLen = Number(parsedResult[`${name}_len`]);
        while (parsedDataArr.length < arrLen) {
          parsedDataArr.push(
            parseResponseValue(
              responseIterator,
              { name, type: output.type.replace("*", "") },
              structs,
              enums
            )
          );
        }
      }
      return parsedDataArr;

    case isTypeNonZero(type):
      return parseResponseValue(responseIterator, output, structs, enums);

    default:
      return parseBaseTypes(type, responseIterator);
  }
};
