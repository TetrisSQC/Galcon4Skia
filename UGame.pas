unit UGame;

interface

uses System.Classes, System.SysUtils,
 System.Generics.Collections, Skia;

const
  gamecolors: Array [0 .. 4] of cardinal = ($FF3B303E, $FF0065C3, $FFB70027,
    $FF248A00, $FFB76700);

type
  IDisplay = interface
    ['{A3E82C50-78B7-49CE-BAE6-AF064058C21C}']
    procedure DrawLine(const ACanvas: ISkCanvas;x1, y1, x2, y2: single; color: cardinal;
      thickness: single = 2; alpha: single = 1);
    procedure DrawQuad(const ACanvas: ISkCanvas;x1, y1, x2, y2: single; color: cardinal;
      alpha: single = 1);
    procedure drawCircle(const ACanvas: ISkCanvas;x, y, outer_radius, inner_radius: single;
      color: cardinal; glow: Boolean = false; alpha: single = 1.0);

    procedure GetMouse(out x, y: single);
    procedure GetDimension(out Width, Height: single);
    procedure PlaySound(const sample: String);
  end;

  TGameScene = class;
  TGameEntity = class;
  TShip = class;
  TTrail = class;
  TAI = class;
  TNode = class;

  TNodeSort = class
    node: TNode;
    tlDist: single;
    blDist: single;
    trDist: single;
    brDist: single;
    midDist: single;

    constructor create(const node: TNode);
  end;

  TNodeList = TList<TNode>;
  TShipList = TList<TShip>;
  TNodeSorter = TList<TNodeSort>;
  TTrailList = TList<TTrail>;
  TAIList = TList<TAI>;

  TGameEntity = class
  private
    FGame: TGameScene;
  public
    constructor create(const Game: TGameScene);
    function Update(const dt: single): Boolean; virtual; abstract;

    property Game: TGameScene read FGame;
  end;

  TNode = class(TGameEntity)
  private
    FSize: single;
    FBaseSize: single;
  public
    x, y: single;
    energy: single;

    team: integer;
    captureTeam: integer;
    selected: Boolean;
    aiVal: single;
    constructor create(const Game: TGameScene; const x, y, size: single);
    function Update(const dt: single): Boolean; override;
    procedure hit(const ship: TShip);

    procedure SetSize(const Value: single);

    property BaseSize: single read FBaseSize;
    property size: single read FSize;
  end;

  TShip = class(TGameEntity)
  public
    x: single;
    y: single;
    deltaX: single;
    deltaY: single;
    speed: single;
    rotation: single;
    energy: single;

    team: integer;
    target: TNode;

    trailTimer: single;
    lastTrail: TTrail;

    constructor create(const node: TNode; target: TNode);
    function Update(const dt: single): Boolean; override;
  end;

  TTrail = class(TGameEntity)
  public
    x: single;
    y: single;
    Width: single;
    rotation: single;
    alpha: single;
    color: cardinal;
    prev: TTrail;
    constructor create(const Game: TGameScene; const x, y: single;
      const color: cardinal);
    function Update(const dt: single): Boolean; override;
  end;

  TAI = class(TGameEntity)
  private
    procedure DoSort(const List: TNodeList);
  public
    team: integer;
    timer: single;
    targets: TNodeList;
    assets: TNodeList;
    delay: single;

    constructor create(const Game: TGameScene; team: integer;
      delay: single = 2.0);
    destructor Destroy; override;
    function Update(const dt: single): Boolean; override;
  end;

  TGameScene = class
  private
    nodes: TNodeList;
    ships: TShipList;
    trails: TTrailList;
    ais: TAIList;
    FDisplay: IDisplay;
    FHoverNode: TNode;
    FGameover: Boolean;
    FTeamWon: integer;

    procedure drawNodes(const ACanvas: ISkCanvas);
    procedure drawShips(const ACanvas: ISkCanvas);
    procedure drawTrails(const ACanvas: ISkCanvas);
    procedure drawMeter(const ACanvas: ISkCanvas);

    procedure initNodes(const num: integer);
    procedure initTeams(const num: integer; const delay: single);

    procedure checkGameOver();

    function addTrail(const x, y: single; const color: cardinal): TTrail;
    function addShip(const node, target: TNode): TShip;
    function addNode(const x, y, size: single): TNode;
    function addAI(const team: integer; const delay: single): TAI;

    function moveShips(const node, target: TNode): integer;

    function overlap(const x, y: single): Boolean;

    procedure Reset;
  public
    constructor create(const Display: IDisplay);
    destructor Destroy; override;

    procedure Init(const nodes, teams: integer;const aidelay: single);

    procedure sendShips();
    function getClosestNode(const x, y: single): TNode;

    procedure Update(const passedTime: single);
    procedure Render(const ACanvas: ISkCanvas);

    procedure PlayPing01;
    procedure playPing02;
    procedure PlayHit;

    property GameOver: Boolean read FGameover;
    property TeamWon: integer read FTeamWon;
  end;

implementation

uses System.Math, System.Generics.Defaults;

{ TGameEntity }
constructor TGameEntity.create(const Game: TGameScene);
begin
  FGame := Game;
end;

{ TNode }
constructor TNode.create(const Game: TGameScene; const x, y, size: single);
begin
  inherited create(Game);
  self.x := x;
  self.y := y;
  SetSize(size);

  team := 0;
  captureTeam := 0;
  energy := 0;
  selected := false;
end;

function TNode.Update(const dt: single): Boolean;
begin
  result := false;
  if (team > 0) and (energy < 1.0) then
  begin
    energy := energy + dt * 0.2;
    if (energy > 1.0) then
      energy := 1.0;
  end;
  if (FSize > FBaseSize) then
  begin
    FSize := FSize - dt * 0.5;
    if (FSize < FBaseSize) then
      FSize := FBaseSize;
  end;
end;

procedure TNode.SetSize(const Value: single);
begin
  FSize := Value;
  FBaseSize := Value;
end;

procedure TNode.hit(const ship: TShip);
begin
  if (team = 0) then
  begin
    if (captureTeam = ship.team) then
    begin
      energy := energy + ship.energy;
      if (energy >= 1.0) then
      begin
        energy := 1.0;
        team := ship.team;
        FGame.PlayPing01();
      end
    end
    else
    begin
      if (energy = 0) then
      begin
        energy := energy + ship.energy;
        captureTeam := ship.team;
      end
      else
      begin
        energy := energy - ship.energy;
        if (energy <= 0) then
        begin
          energy := 0;
          captureTeam := ship.team;
        end;
      end;
    end
  end
  else
  begin
    if (team = ship.team) then
    begin
      energy := energy + ship.energy;
      if (energy >= 1.0) then
      begin
        energy := 1.0;
						// size := size + ship.energy*0.5;
        FSize := FSize + ship.energy * (BaseSize / FSize) * 0.5;
      end;
    end
    else
    begin
      energy := energy - ship.energy;
      if (energy <= 0) then
      begin
        energy := 0;
        team := ship.team;
        FGame.PlayPing01();
      end;
    end;
  end;
  FGame.PlayHit();
end;

{ TShip }
constructor TShip.create(const node: TNode; target: TNode);
begin
  inherited create(node.Game);
  self.x := node.x;
  self.y := node.y;
  self.target := target;
  self.team := node.team;
  self.energy := 0.04;
  speed := 150;

  trailTimer := 0;
  lastTrail := nil;

  rotation := random(100) / 100 * PI * 2;
  deltaX := cos(rotation) * (100 + random(100));
  deltaY := sin(rotation) * (100 + random(100));
end;

function TShip.Update(const dt: single): Boolean;
var
  dx, dy, dist: single;
  angle: single;
begin
  result := false;

  dx := target.x - x;
  dy := target.y - y;
  dist := sqrt(dx * dx + dy * dy);

  if (dist > target.size * 50 + 4) then
  begin
    x := x + deltaX * dt;
    y := y + deltaY * dt;
    deltaX := deltaX - deltaX * dt * 1.2;
    deltaY := deltaY - deltaY * dt * 1.2;

    angle := arctan2(dy, dx);
    deltaX := deltaX + cos(angle) * speed * dt;
    deltaY := deltaY + sin(angle) * speed * dt;
  end
  else
  begin
    target.hit(self);
    result := true; // Remove
  end;

  if assigned(lastTrail) then
  begin
    dx := self.x - lastTrail.x;
    dy := self.y - lastTrail.y;
    dist := sqrt(dx * dx + dy * dy);
    angle := arctan2(dy, dx);
    lastTrail.Width := dist;
    lastTrail.rotation := angle;
  end;

  trailTimer := trailTimer - dt;
  if (trailTimer <= 0) then
  begin
    lastTrail := Game.addTrail(x, y, gamecolors[team]);
    trailTimer := 0.1;
  end;
end;

{ TTrail }
constructor TTrail.create(const Game: TGameScene; const x, y: single;
  const color: cardinal);
begin
  inherited create(Game);
  self.x := x;
  self.y := y;
  self.color := color;
  Width := 0;
  rotation := 0;
  alpha := 1.0;
end;

function TTrail.Update(const dt: single): Boolean;
begin
  result := false;
  alpha := alpha - dt;
  if (alpha <= 0) then
  begin
    alpha := 0;
    Width := 0;
    rotation := 0;
    result := true;
  end;
end;

{ TAI }
constructor TAI.create(const Game: TGameScene; team: integer;
  delay: single = 2.0);
begin
  inherited create(Game);
  self.team := team;
  self.delay := delay;
  timer := delay + random(100) / 100 * delay;

  targets := TNodeList.create;
  assets := TNodeList.create;
end;

destructor TAI.Destroy;
begin
  targets.free;
  assets.free;
  inherited;
end;

procedure TAI.DoSort(const List: TNodeList);
begin
  List.Sort(TComparer<TNode>.Construct(
    function(const e0, e1: TNode): integer
    begin
      if (e1.y < e0.y) then
        result := 1
      else if (e1.y > e0.y) then
        result := -1
      else
        result := 0;
    end));
end;

function TAI.Update(const dt: single): Boolean;
var
  localX, localY: single;
  nodes: TNodeList;
  asset, target: TNode;
  num, i: integer;
  node: TNode;
  dx, dy, dist: single;
  needed: integer;
  sent: integer;
begin
  timer := timer - dt;
  result := false;
  if (timer <= 0) then
  begin
				// get local center
    localX := 0;
    localY := 0;
    nodes := Game.nodes;
    num := 0;
    for i := 0 to nodes.Count - 1 do
    begin
      node := nodes[i];
      if (node.team = team) then
      begin
        localX := localX + node.x;
        localY := localY + node.y;
        inc(num);
      end;
    end;
    if num > 0 then
    begin
      localX := localX / num;
      localY := localY / num;
    end;

    targets.Clear;
    for i := 0 to nodes.Count - 1 do
    begin
      node := nodes[i];
      if (node.team <> team) then
      begin
        dx := node.x - localX;
        dy := node.y - localY;
        dist := sqrt(dx * dx + dy * dy);
        if (node.team <> 0) then
          node.aiVal := dist + random(100)
        else
          node.aiVal := dist;
        targets.Add(node);
      end;
    end;
    DoSort(targets);

    assets.Clear;
    if targets.Count > 0 then
    begin
      target := targets[0];
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        if (node.team = team) then
        begin
          dx := node.x - target.x;
          dy := node.y - target.y;
          dist := sqrt(dx * dx + dy * dy);
          node.aiVal := -node.size * node.energy + dist * 0.01;
          assets.Add(node);
        end;
      end;
      DoSort(assets);

      needed := trunc(target.size * 50);
      for i := assets.Count - 1 downto 0 do
        if needed > 0 then
        begin
          asset := assets[i];
          sent := Game.moveShips(asset, target);
          needed := needed - sent;
        end;
    end;

    timer := delay + random(100) / 100 * delay;
  end;
end;

{ TNodeSort }
constructor TNodeSort.create(const node: TNode);
begin
  self.node := node;
end;

{ TGameScene }
procedure TGameScene.Init(const nodes, teams: integer;const aidelay: single);
begin
  Reset;
  FGameover := false;
  initNodes(nodes);
  initTeams(teams, aidelay);
end;

procedure TGameScene.initNodes(const num: integer);
var
  i: integer;
  x, y, size: single;
  W, H: single;
  overflow: integer;
begin
  FDisplay.GetDimension(W, H);
  for i := 0 to num - 1 do
  begin
    x := random(trunc(W) - 100) + 50;
    y := random(trunc(H) - 100) + 50;
    size := random(100) / 100 * 0.5 + 0.3;
    overflow := 0;
    while (overlap(x, y)) and (overflow < 1000) do
    begin
      x := random(trunc(W) - 100) + 50;
      y := random(trunc(H) - 100) + 50;
      inc(overflow);
    end;
    if (overflow < 1000) then
      addNode(x, y, size);
  end;
end;

procedure TGameScene.initTeams(const num: integer; const delay: single);
var
  dx, dy: single;
  i: integer;
  node: TNode;
  sorter: TNodeSorter;
  sortNode: TNodeSort;

  procedure DoSort(const Value: integer);
  begin
    sorter.Sort(TComparer<TNodeSort>.Construct(
      function(const e0, e1: TNodeSort): integer
      begin
        result := 0;
        case Value of
          0:
            if (e1.blDist < e0.blDist) then
              result := 1
            else if (e1.blDist > e0.blDist) then
              result := -1;
          1:
            if (e1.trDist < e0.trDist) then
              result := 1
            else if (e1.trDist > e0.trDist) then
              result := -1;
          2:
            if (e1.midDist < e0.midDist) then
              result := 1
            else if (e1.midDist > e0.midDist) then
              result := -1;
          3:
            if (e1.tlDist < e0.tlDist) then
              result := 1
            else if (e1.tlDist > e0.tlDist) then
              result := -1;
          4:
            if (e1.brDist < e0.brDist) then
              result := 1
            else if (e1.brDist > e0.brDist) then
              result := -1;
        end;
      end));
  end;

var
  W, H: single;
  obj: TObject;
begin
  sorter := TNodeSorter.create;
  FDisplay.GetDimension(W, H);
  try
    if (num = 2) then
    begin
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        sortNode := TNodeSort.create(node);
        dx := node.x - 0;
        dy := 0;
        sortNode.blDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := 0;
        sortNode.trDist := sqrt(dx * dx + dy * dy);
        sorter.Add(sortNode);
      end;

      DoSort(0);
      TNodeSort(sorter[0]).node.team := 1;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(1);
      TNodeSort(sorter[0]).node.team := 2;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      addAI(2, delay);
    end
    else if (num = 3) then
    begin
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        sortNode := TNodeSort.create(node);
        dx := node.x - 0;
        dy := node.y - H;
        sortNode.blDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := node.y - 0;
        sortNode.trDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W * 0.5;
        dy := node.y - H * 0.5;
        sortNode.midDist := sqrt(dx * dx + dy * dy);
        sorter.Add(sortNode);
      end;

      DoSort(0);
      TNodeSort(sorter[0]).node.team := 1;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(1);
      TNodeSort(sorter[0]).node.team := 2;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(2);
      TNodeSort(sorter[0]).node.team := 3;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      addAI(2, delay);
      addAI(3, delay);
    end
    else if (num = 4) then
    begin
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        sortNode := TNodeSort.create(node);
        dx := node.x - 0;
        dy := node.y - 0;
        sortNode.tlDist := sqrt(dx * dx + dy * dy);
        dx := node.x - 0;
        dy := node.y - H;
        sortNode.blDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := node.y - 0;
        sortNode.trDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := node.y - H;
        sortNode.brDist := sqrt(dx * dx + dy * dy);
        sorter.Add(sortNode);
      end;

      DoSort(0);
      TNodeSort(sorter[0]).node.team := 1;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(3);
      TNodeSort(sorter[0]).node.team := 2;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(1);
      TNodeSort(sorter[0]).node.team := 3;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(4);
      TNodeSort(sorter[0]).node.team := 4;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      addAI(2, delay);
      addAI(3, delay);
      addAI(4, delay);
    end;
  finally
    for i := 0 to sorter.Count - 1 do
    begin
      obj := sorter[i];
      FreeAndNil(obj);
    end;
    sorter.free;
  end;
end;

function TGameScene.overlap(const x: single; const y: single): Boolean;
var
  i: integer;
  node: TNode;
  dx, dy, dist: single;
begin
  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    dx := node.x - x;
    dy := node.y - y;
    dist := sqrt(dx * dx + dy * dy);
    if (dist < 100) then
    begin
      result := true;
      exit;
    end;
  end;
  result := false;
end;

procedure TGameScene.checkGameOver();
var
  i: integer;
  node: TNode;
  activeTeams: Array of integer;
  ship: TShip;

  function Search(const team: integer): integer;
  var
    i: integer;
  begin
    for i := 0 to high(activeTeams) do
      if activeTeams[i] = team then
      begin
        result := i;
        exit;
      end;
    result := -1;
  end;

begin
  Setlength(activeTeams, 0);
  try
    for i := 0 to nodes.Count - 1 do
    begin
      node := nodes[i];
      if (node.team > 0) and (Search(node.team) = -1) then
      begin
        Setlength(activeTeams, length(activeTeams) + 1);
        activeTeams[high(activeTeams)] := node.team;
      end;
    end;

    for i := 0 to ships.Count - 1 do
    begin
      ship := ships[i];
      if (ship.team > 0) and (Search(ship.team) = -1) then
      begin
        Setlength(activeTeams, length(activeTeams) + 1);
        activeTeams[high(activeTeams)] := ship.team;
      end;
    end;

    if high(activeTeams) = 0 then
    begin
      FGameover := true;
      FTeamWon := activeTeams[0];
    end;
  finally
    Setlength(activeTeams, 0);
  end;
end;

function TGameScene.moveShips(const node, target: TNode): integer;
var
  num, j: integer;
begin
  result := 0;
  if (node = target) then
    exit;
  num := trunc(node.size * node.energy * 50);
  for j := 0 to num - 1 do
    addShip(node, target);
  node.energy := 0;
  playPing02();

  result := num;
end;

function TGameScene.addNode(const x, y, size: single): TNode;
begin
  result := TNode.create(self, x, y, size);
  nodes.Add(result);
end;

function TGameScene.addShip(const node, target: TNode): TShip;
begin
  result := TShip.create(node, target);
  ships.Add(result);
end;

function TGameScene.addTrail(const x, y: single; const color: cardinal): TTrail;
begin
  result := TTrail.create(self, x, y, color);
  trails.Add(result);
end;

function TGameScene.addAI(const team: integer; const delay: single): TAI;
begin
  result := TAI.create(self, team, delay);
  ais.Add(result);
end;

procedure TGameScene.Update(const passedTime: single);
var
  dt: single;
  i: integer;
  x, y: single;
  node: TNode;
  ship: TShip;
  trail: TTrail;
  ai: TAI;
begin
  FDisplay.GetMouse(x, y);
  FHoverNode := getClosestNode(x, y);

  dt := passedTime;
// juggler.advanceTime(dt);
  dt := dt * 0.5;

  for i := nodes.Count - 1 downto 0 do
  begin
    node := nodes[i];
    if node.Update(dt) then
    begin
      FreeAndNil(node);
      nodes.Delete(i);
    end;
  end;

  for i := ships.Count - 1 downto 0 do
  begin
    ship := ships[i];
    if ship.Update(dt) then
    begin
      FreeAndNil(ship);
      ships.Delete(i);
    end;
  end;

  for i := trails.Count - 1 downto 0 do
  begin
    trail := trails[i];
    if trail.Update(dt) then
    begin
      FreeAndNil(trail);
      trails.Delete(i);
    end;
  end;

  for i := ais.Count - 1 downto 0 do
  begin
    ai := ais[i];
    if ai.Update(dt) then
    begin
      FreeAndNil(ai);
      ais.Delete(i);
    end;
  end;

  if (not FGameover) then
    checkGameOver();
end;

procedure TGameScene.Render(const ACanvas: ISkCanvas);
begin
  drawNodes(ACanvas);
  drawShips(ACanvas);
  drawTrails(ACanvas);
  drawMeter(ACanvas);
end;

procedure TGameScene.drawNodes(const ACanvas: ISkCanvas);
var
  i: integer;
  node: TNode;
  size: single;
  dx, dy, dist: single;
  mx, my: single;
  nodex, nodey, angle: single;
  targetX, targetY: single;
  minSize: single;
begin
  if not assigned(FDisplay) then
    exit;
  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    size := node.size * node.energy * 50;
    if (size < 0) then
      size := 0;
    if (node.team = 0) then
    begin
      FDisplay.drawCircle(ACanvas, node.x, node.y, node.size * 50 + 4, node.size * 50,
        gamecolors[0]);
      if (node.captureTeam <> 0) then
      begin
        minSize := node.size * 50 - size;
        FDisplay.drawCircle(ACanvas, node.x, node.y, node.size * 50, minSize,
          gamecolors[node.captureTeam]);
        FDisplay.drawCircle(ACanvas, node.x, node.y, size, 0,
          gamecolors[node.captureTeam]);

      end;
    end
    else
    begin
      FDisplay.drawCircle(ACanvas, node.x, node.y, node.size * 50 + 4, node.size * 50,
        gamecolors[node.team]);
      FDisplay.drawCircle(ACanvas, node.x, node.y, size, 0, gamecolors[node.team]);
      FDisplay.drawCircle(ACanvas, node.x, node.y, size + 25, 0,
        gamecolors[node.team], true);
    end;

    if (node.selected) or (node = FHoverNode) then
      FDisplay.drawCircle(ACanvas, node.x, node.y, node.size * 50 + 8,
        node.size * 50 + 5, $FFFFFFFF);

    if (node.selected) then
    begin
      FDisplay.GetMouse(mx, my);
      dx := mx - node.x;
      dy := my - node.y;
      dist := sqrt(dx * dx + dy * dy);
      if (dist >= node.size * 50 + 5) then
      begin
        angle := arctan2(dy, dx);
        nodex := node.x + cos(angle) * (node.size * 50 + 7);
        nodey := node.y + sin(angle) * (node.size * 50 + 7);
        if assigned(FHoverNode) then
        begin
          if (node <> FHoverNode) then
          begin
            dx := node.x - FHoverNode.x;
            dy := node.y - FHoverNode.y;
            angle := arctan2(dy, dx);
            nodex := node.x + cos(angle + PI) * (node.size * 50 + 7);
            nodey := node.y + sin(angle + PI) * (node.size * 50 + 7);
            targetX := FHoverNode.x + cos(angle) * (FHoverNode.size * 50 + 7);
            targetY := FHoverNode.y + sin(angle) * (FHoverNode.size * 50 + 7);
            FDisplay.DrawLine(ACanvas, nodex, nodey, targetX, targetY, $FFFFFFFF, 2);
          end;
        end
        else
          FDisplay.DrawLine(ACanvas, nodex, nodey, mx, my, $FFFFFFFF, 2);
      end;
    end;
  end;
end;

procedure TGameScene.drawShips(const ACanvas: ISkCanvas);
var
  i: integer;
  ship: TShip;
begin
  for i := 0 to ships.Count - 1 do
  begin
    ship := ships[i];
    FDisplay.DrawQuad(ACanvas, ship.x-1, ship.y-1, ship.x + 1, ship.y + 1,
      gamecolors[ship.team]);
  end;
end;

procedure TGameScene.drawTrails(const ACanvas: ISkCanvas);
var
  i: integer;
  trail: TTrail;
begin
  if trails.Count = 0 then
    exit;

  for i := 0 to trails.Count - 1 do
  begin
    trail := trails[i];
    if trail.Width > 0 then
      FDisplay.DrawLine(ACanvas, trail.x, trail.y, trail.x + trail.Width *
        cos(trail.rotation), trail.y + trail.Width * sin(trail.rotation),
        trail.color, 2, trail.alpha);
  end;
end;

procedure TGameScene.drawMeter(const ACanvas: ISkCanvas);
var
  teamStats: Array [0 .. 4] of single;
  node: TNode;
  i: integer;
  total: single;
  team1Width, team2Width, team3Width, team4Width: single;
  y, thickness: single;
  W, H: single;
begin
  FDisplay.GetDimension(W, H);
  teamStats[0] := 0;
  teamStats[1] := 0;
  teamStats[2] := 0;
  teamStats[3] := 0;
  teamStats[4] := 0;

  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    if (node.team > 0) then
      teamStats[node.team] := teamStats[node.team] + node.size;
  end;

  total := teamStats[1] + teamStats[2] + teamStats[3] + teamStats[4];
  team1Width := (teamStats[1] / total) * W;
  team2Width := (teamStats[2] / total) * W;
  team3Width := (teamStats[3] / total) * W;
  team4Width := (teamStats[4] / total) * W;
  thickness := 6;

  y := H - thickness * 0.5;
  with FDisplay do
  begin
    DrawLine(ACanvas, 0, y, team1Width, y, gameColors[1], thickness);
    DrawLine(ACanvas, team1Width, y, team1Width + team2Width, y, gameColors[2], thickness);
    DrawLine(ACanvas, team1Width + team2Width, y, team1Width + team2Width + team3Width,
      y, gameColors[3], thickness);
    DrawLine(ACanvas, team1Width + team2Width + team3Width, y, team1Width + team2Width +
      team3Width + team4Width, y, gameColors[4], thickness);
  end;
end;

procedure TGameScene.Reset;
var
  i: integer;
  obj: TObject;
begin
  FGameover := true;
  for i := 0 to nodes.Count - 1 do
  begin
    obj := nodes[i];
    FreeAndNil(obj);
  end;
  for i := 0 to ships.Count - 1 do
  begin
    obj := ships[i];
    FreeAndNil(obj);
  end;

  for i := 0 to trails.Count - 1 do
  begin
    obj := trails[i];
    FreeAndNil(obj);
  end;

  for i := 0 to ais.Count - 1 do
  begin
    obj := ais[i];
    FreeAndNil(obj);
  end;

  nodes.Clear;
  ships.Clear;
  trails.Clear;
  ais.Clear;
end;

procedure TGameScene.PlayPing01;
begin
  FDisplay.PlaySound('ping01');
end;

procedure TGameScene.playPing02;
begin
  FDisplay.PlaySound('ping02');
end;

procedure TGameScene.PlayHit;
var
  i: integer;
begin
  i := random(5) + 1;
  FDisplay.PlaySound('hit0' + inttostr(i));
end;

constructor TGameScene.create(const Display: IDisplay);
begin
  FDisplay := Display;
  nodes := TNodeList.create;
  ships := TShipList.create;
  trails := TTrailList.create;
  ais := TAIList.create;
end;

destructor TGameScene.Destroy;
begin
  Reset;
  nodes.free;
  ships.free;
  trails.free;
  ais.free;
  inherited;
end;

function TGameScene.getClosestNode(const x: single; const y: single): TNode;
var
  closest: TNode;
  min: single;
  i: integer;
  dx, dy, dist: single;
  node: TNode;
begin
  closest := nil;
  min := 70;

  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    dx := node.x - x;
    dy := node.y - y;
    dist := sqrt(dx * dx + dy * dy);
    if (dist < node.size * 50 + 20) and (dist < min) then
    begin
      min := dist;
      closest := node;
    end;
  end;
  result := closest;
end;

procedure TGameScene.sendShips;
var
  i: integer;
  node: TNode;
begin
  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    if (node.team = 1) and (node.selected) and assigned(FHoverNode) then
      moveShips(node, FHoverNode);
    node.selected := false;
  end;
end;

end.

