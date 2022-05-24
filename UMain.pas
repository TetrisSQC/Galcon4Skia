unit UMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  Skia, Skia.FMX,
  UGame, Bass, FMX.Layouts;

type
  TfrmMain = class(TForm, IDisplay)
    pbBackground: TSkAnimatedPaintBox;
    lblLevel: TSkLabel;
    lblDescription: TSkLabel;
    layDescription: TLayout;
    svgLogo: TSkSvg;
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure pbBackgroundAnimationDraw(ASender: TObject;
      const ACanvas: ISkCanvas; const ADest: TRectF; const AProgress: Double;
      const AOpacity: Single);
    procedure FormActivate(Sender: TObject);
  private
    { Private-Deklarationen }
    FGame: TGameScene;
    FLastTick: UInt64;
    FLevel: integer;
    FMouse: TPoint;
    FMouseDown: Boolean;
    FPaused: Boolean;
    FStart: UInt64;

    FEffect: ISkRuntimeEffect;
    FPaint: ISkPaint;

    FMusicChannel: Cardinal;

    FHit: array [0 .. 6] of Cardinal;
    FPing: array [0 .. 2] of Cardinal;
    FLaunch: Cardinal;

    procedure LoadEffect(Filename: string; var Handle: Cardinal);

    procedure DrawLine(const ACanvas: ISkCanvas; x1, y1, x2, y2: Single;
      color: Cardinal; thickness: Single = 2; alpha: Single = 1);
    procedure DrawQuad(const ACanvas: ISkCanvas; x1, y1, x2, y2: Single;
      color: Cardinal; alpha: Single = 1);
    procedure drawCircle(const ACanvas: ISkCanvas;
      X, Y, outer_radius, inner_radius: Single; color: Cardinal;
      glow: Boolean = false; alpha: Single = 1.0);

    procedure GetMouse(out X, Y: Single);
    procedure GetDimension(out Width, Height: Single);
    procedure PlaySound(const sample: String);

    procedure SetLevel(const ALevel: integer);
  public
    { Public-Deklarationen }
    procedure StartGame;
  end;

var
  frmMain: TfrmMain;

implementation

uses System.IOUtils, FMX.Ani;

{$R *.fmx}

// Shader: https://shaders.skia.org
const
  levelData: array [0 .. 11, 0 .. 2] of Single = (
    // nodes, teams, ai delay
    (5, 2, 4), (6, 2, 3.5), (8, 2, 3), (10, 2, 3), (9, 3, 4), (12, 3, 3.5),
    (15, 3, 3), (6, 3, 2.5), (16, 4, 3), (18, 4, 2.5), (12, 4, 2),
    (20, 4, 1.5));

  GalaxyShader = 'uniform vec3 iResolution;' + sLinebreak +
    'uniform float iTime;' + sLinebreak + 'const int iterations = 17;' +
    sLinebreak + 'const float formuparam = 0.53;' + sLinebreak +
    'const int volsteps = 20;' + sLinebreak + 'const float stepsize = 0.1;' +
    sLinebreak + 'const float zoom   = 0.800;' + sLinebreak +
    'const float tile   = 0.850;' + sLinebreak + 'const float speed  = 0.002;' +
    sLinebreak + 'const float brightness = 0.0005;' + sLinebreak +
    'const float darkmatter = 0.300;' + sLinebreak +
    'const float distfading = 0.750;' + sLinebreak +
    'const float saturation = 0.750;' + sLinebreak +
    'float SCurve (float value) {' + sLinebreak + '    if (value < 0.5)' +
    sLinebreak + '    {' + sLinebreak +
    '        return value * value * value * value * value * 16.0;' + sLinebreak
    + '    }' + sLinebreak + '    value -= 1.0;' + sLinebreak +
    '    return value * value * value * value * value * 16.0 + 1.0;' +
    sLinebreak + '}' + sLinebreak + 'vec4 main(vec2 fragCoord )' + sLinebreak +
    '{' + sLinebreak + '	vec2 uv=fragCoord.xy/iResolution.xy-.5;' + sLinebreak
    + '	uv.y*=iResolution.y/iResolution.x;' + sLinebreak +
    '	vec3 dir=vec3(uv*zoom,1.);' + sLinebreak + '	float time=iTime*speed+.25;'
    + sLinebreak + '	float a1=.5;' + sLinebreak + '	float a2=.8;' + sLinebreak
    + '	mat2 rot1=mat2(cos(a1),sin(a1),-sin(a1),cos(a1));' + sLinebreak +
    '	mat2 rot2=mat2(cos(a2),sin(a2),-sin(a2),cos(a2));' + sLinebreak +
    '	dir.xz*=rot1;' + sLinebreak + '	dir.xy*=rot2;' + sLinebreak +
    '	vec3 from=vec3(1.,.5,0.5);' + sLinebreak +
    '	from+=vec3(time*2.,time,-2.);' + sLinebreak + '	from.xz*=rot1;' +
    sLinebreak + '	from.xy*=rot2;' + sLinebreak + '	float s=0.1,fade=1.;' +
    sLinebreak + '	vec3 v=vec3(0.);' + sLinebreak +
    '	for (int r=0; r<volsteps; r++) {' + sLinebreak +
    '		vec3 p=from+s*dir*.5;' + sLinebreak +
    '		p = abs(vec3(tile)-mod(p,vec3(tile*2.)));' + sLinebreak +
    '		float pa,a=pa=0.;' + sLinebreak +
    '		for (int i=0; i<iterations; i++) {' + sLinebreak +
    '			p=abs(p)/dot(p,p)-formuparam;' + sLinebreak +
    '			a+=abs(length(p)-pa);' + sLinebreak + '			pa=length(p);' +
    sLinebreak + '		}' + sLinebreak +
    '		float dm=max(0.,darkmatter-a*a*.001);' + sLinebreak +
    '		a = pow(a, 2.5);' + sLinebreak + '		if (r>6) fade*=1.-dm;' +
    sLinebreak + '		v+=fade;' + sLinebreak +
    '		v+=vec3(s,s*s,s*s*s*s)*a*brightness*fade;' + sLinebreak +
    '		fade*=distfading;' + sLinebreak + '		s+=stepsize;' + sLinebreak + '	}'
    + sLinebreak + '	v=mix(vec3(length(v)),v,saturation);' + sLinebreak +
    '    vec4 C = vec4(v*.01,1.);' + sLinebreak + '     	C.r = pow(C.r, 0.35);'
    + sLinebreak + ' 	 	C.g = pow(C.g, 0.36);' + sLinebreak +
    ' 	 	C.b = pow(C.b, 0.4);' + sLinebreak + '    vec4 L = C;' + sLinebreak +
    '    	C.r = mix(L.r, SCurve(C.r), 1.0);' + sLinebreak +
    '    	C.g = mix(L.g, SCurve(C.g), 0.9);' + sLinebreak +
    '    	C.b = mix(L.b, SCurve(C.b), 0.6);' + sLinebreak + '	return C;}';

  Description = 'HOW TO PLAY' + sLinebreak +
    '1. Click and drag over planets to send ships' + sLinebreak +
    '2. Conquer planets to produce more ships' + sLinebreak +
    '3. Eliminate the enemies';

function RandomSong(ADir: String): String;
var
  LList: TStringlist;
  SearchRec: TSearchRec;
  dosError: integer;
begin
  ADir := IncludeTrailingPathDelimiter(ADir);
  dosError := FindFirst(ADir + '*.*', faArchive, SearchRec);
  LList := TStringlist.Create;
  try
    while dosError = 0 do
    begin
      LList.Add(ADir + SearchRec.Name);
      dosError := FindNext(SearchRec);
    end;
    FindClose(SearchRec);
    result := LList[Random(LList.Count - 1)];
  finally
    LList.Free;
  end;
end;

procedure UpdateFmxObject(const AObject: TFmxObject);
begin
  if AObject.Tag > 0 then
  begin
    AObject.Tag := AObject.Tag - 1;
    if AObject.Tag < 1 then
      TAnimator.AnimateFloat(AObject, 'Opacity', 0);
  end;
end;

procedure TfrmMain.LoadEffect(Filename: string; var Handle: Cardinal);
begin
  Filename := 'Effects\' + Filename;
  Handle := BASS_SampleLoad(false, PChar(Filename), 0, 0, 3,
    BASS_SAMPLE_OVER_POS or BASS_UNICODE);
end;

procedure TfrmMain.StartGame;
begin
  FGame.Init(trunc(levelData[FLevel][0]), trunc(levelData[FLevel][1]),
    levelData[FLevel][2]);
end;

procedure TfrmMain.FormActivate(Sender: TObject);
var
  i: integer;
begin
  OnActivate := nil;

  lblLevel.Opacity := 0;
  lblDescription.Text := Description;
  layDescription.Tag := 500;

  if BASS_Init(-1, 44100, 0, 0, nil) then
  begin
    FMusicChannel := BASS_MusicLoad(false, PWideChar(RandomSong('Music')), 0, 0,
      BASS_STREAM_AUTOFREE or BASS_UNICODE, 44100);

    for i := 0 to 6 do
      LoadEffect(format('hit0%d.mp3', [i + 1]), FHit[i]);
    for i := 0 to 2 do
      LoadEffect(format('ping0%d.mp3', [i + 1]), FPing[i]);
    LoadEffect('launch01.mp3', FLaunch);

    Bass_ChannelPlay(FMusicChannel, true);
  end;

  FGame := TGameScene.Create(Self);
  FStart := TThread.GetTickCount64;

  FEffect := TSkRuntimeEffect.MakeForShader(GalaxyShader);

  FPaint := TSkPaint.Create;
  FPaint.Shader := FEffect.MakeShader(true);

  SetLevel(0);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FGame);
  BASS_Free;
end;

procedure TfrmMain.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FMouseDown := true;
end;

procedure TfrmMain.FormMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Single);
var
  node: TNode;
begin
  if FPaused then
    exit;

  FMouse := Point(trunc(X), trunc(Y));
  if FMouseDown then
  begin
    node := FGame.getClosestNode(X, Y);
    if assigned(node) and ((node.team = 1) or (node.captureTeam = 1)) then
      node.selected := true;
  end;

end;

procedure TfrmMain.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FMouseDown := false;
  FGame.sendShips();
end;

procedure TfrmMain.DrawLine(const ACanvas: ISkCanvas; x1, y1, x2, y2: Single;
  color: Cardinal; thickness: Single = 2; alpha: Single = 1);
var
  LPaint: ISkPaint;
begin
  LPaint := TSkPaint.Create;
  LPaint.StrokeWidth := thickness;
  LPaint.color := color;
  LPaint.AlphaF := alpha;
  ACanvas.DrawLine(x1, y1, x2, y2, LPaint);
end;

procedure TfrmMain.DrawQuad(const ACanvas: ISkCanvas; x1, y1, x2, y2: Single;
  color: Cardinal; alpha: Single = 1);
var
  LPaint: ISkPaint;
begin
  LPaint := TSkPaint.Create;
  LPaint.color := color;
  LPaint.AlphaF := alpha;
  ACanvas.DrawRect(RectF(x1, y2, x2, y2), LPaint);
end;

procedure TfrmMain.drawCircle(const ACanvas: ISkCanvas;
  X, Y, outer_radius, inner_radius: Single; color: Cardinal;
  glow: Boolean = false; alpha: Single = 1.0);
var
  a: Single;
  radius: Single;
  LPaint: ISkPaint;
begin
  a := ((color shr 24) and $FF) / 255;
  if (a <= 0) or (alpha < 0) then
    exit;

  if alpha < 1 then
    a := a * alpha;

  color := (trunc(255 * a) and $FF) shl 24 or (color and $00FFFFFF);

  radius := inner_radius;

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := true;
  if glow then
    LPaint.Blender := TSkBlender.MakeMode(TSkBlendMode.Plus);

  while radius < outer_radius do
  begin
    if glow then
      LPaint.color := (trunc((1 - radius / outer_radius) * a * 128) and $FF)
        shl 24 or (color and $00FFFFFF)
    else
      LPaint.color := color;

    LPaint.StrokeWidth := 2;
    LPaint.Style := TSkPaintStyle.Stroke;
    ACanvas.drawCircle(X, Y, radius, LPaint);
    radius := radius + 1;
  end;
end;

procedure TfrmMain.GetMouse(out X, Y: Single);
begin
  X := FMouse.X;
  Y := FMouse.Y;
end;

procedure TfrmMain.GetDimension(out Width, Height: Single);
begin
  Width := ClientWidth;
  Height := ClientHeight;
end;

procedure TfrmMain.PlaySound(const sample: String);
var
  Handle: Cardinal;
  ch: HCHANNEL;
begin
  if sample = 'hit01' then
    Handle := FHit[0]
  else if sample = 'hit02' then
    Handle := FHit[1]
  else if sample = 'hit03' then
    Handle := FHit[2]
  else if sample = 'hit04' then
    Handle := FHit[3]
  else if sample = 'hit05' then
    Handle := FHit[4]
  else if sample = 'hit06' then
    Handle := FHit[5]
  else if sample = 'launch01' then
    Handle := FLaunch
  else if sample = 'ping01' then
    Handle := FPing[0]
  else if sample = 'ping02' then
    Handle := FPing[1]
  else if sample = 'ping03' then
    Handle := FPing[2]
  else
    exit;

  ch := BASS_SampleGetChannel(Handle, false);
  BASS_ChannelSetAttribute(ch, BASS_ATTRIB_VOL, 0.2);
  Bass_ChannelPlay(ch, false);
end;

procedure TfrmMain.SetLevel(const ALevel: integer);
begin
  FLevel := ALevel;
  lblLevel.Text := IntToStr(FLevel + 1);
  lblLevel.Tag := 250;
  TAnimator.AnimateFloat(lblLevel, 'Opacity', 1);

  if (FLevel < high(levelData)) then
    StartGame;
end;

procedure TfrmMain.pbBackgroundAnimationDraw(ASender: TObject;
  const ACanvas: ISkCanvas; const ADest: TRectF; const AProgress: Double;
  const AOpacity: Single);
var
  Tick: UInt64;
begin
  Tick := TThread.GetTickCount64;

  if not FPaused then
  begin
    FGame.Update((Tick - FLastTick) / 1000);
    FLastTick := Tick;
  end;

  // ---------------------------------------------------------------------------

  UpdateFmxObject(lblLevel);
  UpdateFmxObject(layDescription);

  if assigned(FEffect) and assigned(FPaint) then
  begin
    if FEffect.UniformExists('iResolution') then
    begin
      if FEffect.UniformType['iResolution'] = TSkRuntimeEffectUniformType.Float3
      then
        FEffect.SetUniform('iResolution', [ADest.Width, ADest.Height, 0])
      else
        FEffect.SetUniform('iResolution', PointF(ADest.Width, ADest.Height));
    end;

    if FEffect.UniformExists('iTime') then
      FEffect.SetUniform('iTime', (Tick - FStart) / 1000);

    ACanvas.DrawRect(ADest, FPaint);
  end
  else
    ACanvas.Clear(TAlphaColorRec.Black);

  FGame.Render(ACanvas);

  // ---------------------------------------------------------------------------

  if FGame.gameover then
  begin
    if (FGame.TeamWon = 1) then
      SetLevel(FLevel + 1)
    else
      SetLevel(FLevel);
  end;
end;

end.
