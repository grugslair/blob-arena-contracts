const randomElement = (array) => {
  return array[Math.floor(Math.random() * array.length)];
};

const nRandomElements = (array, n) => {
  if (n > array.length) {
    throw new Error("n is larger than the array length");
  }
};

export const randomIndexes = (len, n) => {
  if (n > len) {
    throw new Error("n must be less than or equal to len");
  }
  let indexes = [...Array(len).keys()];
  let randomIndexes = [];
  for (let i = 0; i < n; i++) {
    const randomIndex = Math.floor(Math.random() * indexes.length);
    randomIndexes.push(indexes[randomIndex]);
    indexes.splice(randomIndex, 1);
  }
  return randomIndexes;
};
