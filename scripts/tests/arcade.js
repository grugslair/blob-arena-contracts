export const runArcadeBattles = async (
  caller,
  signer,
  contract,
  games,
  attacks
) => {};

export const makeArcadeChallenge = (
  caller,
  contract,
  ChallengeId,
  collectionAddress,
  tokenId,
  attacks
) => {
  return contract.populate("start_challenge", {
    game_id: gameId,
    token_id: tokenId,
    attack_id: attackId,
  });
};
