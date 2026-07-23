enum BlockType {
  sceneHeading,
  action,
  character,
  dialogue,
  parenthetical,
  transition;

  bool get isSceneHeading => this == BlockType.sceneHeading;
}
