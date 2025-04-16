const randomElement = (array) => {
  return array[Math.floor(Math.random() * array.length)];
};

const nRandomElements = (array, n) => {
  if (n > array.length) {
    throw new Error("n is larger than the array length");
  }
};
