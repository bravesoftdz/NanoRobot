unit BaseUnit;

interface

uses
  SysUtils,     // IntToStr
  ComCtrls,     // TStatusBar
  Math,         // Min, Max
  Classes,      // TList
  Graphics,     // TCanvas
  Types,        // TPoint
  Forms,        // TApplication
  StdCtrls,     // TListBox

  PrefUnit;

const
  BaseStartFood = 20; // How much food to start with
  BaseFeedFood  = 1;  // How much food to feed someone asking

type TBaseState = (stCreated, stRunning, stHibernate, stDead);


type TBaseObject = class(TObject)
  protected
    Id      : integer;    // Unique ID of this object
    Name    : string;     // Name of the object
    Pos     : TPoint;     // Position in the world space
    State   : TBaseState; // State of the object
    Food    : Real;       // Amount of food in stomack
    DebugOn : boolean;

    Pref    : TPref;     // The preference record
  public

    //---  constructors / destructors and such ---------------------------------

    constructor Create (pPos : TPoint; pPref  : TPref ); virtual;

    //--- General procedures ---------------------------------------------------

    // Act in the world

    procedure   Act (bDebug : boolean); virtual;

    // Return status

    function    InqState: TBaseState; virtual;
    function    InqId   : integer; virtual;

    // Return your position

    function    InqPos : TPoint; virtual;
    function    InqRad : integer; virtual;

    // Return the food amount you have

    function    InqFood : real; virtual;

    // Feed an object some food , return how much you was feed

    function    Feed (pObj : TBaseObject) : real; virtual;

    // Get/loose food and  return how much you got/lost

    function    Eat  (fFood : real) : real; virtual;
    function    Rob  (fFood : real) : real; virtual;

    // Return info about this object

    function InqInfo (w : string): string; virtual;

    procedure SetArea (rArea : TRect); virtual;

    //--- Drawing routines -----------------------------------------------------

    procedure   Draw (); virtual;

  end;

implementation

  var CurId : integer = 1;

//------------------------------------------------------------------------------
// Constructor
//
constructor TBaseObject.Create(pPos : TPoint; pPref  : TPref );
begin
  inherited Create;

  // Initiate a unique Id for this object

  Self.Id := CurId;
  CurId := CurId + 1;

  if length(Self.Name) = 0 then
    Self.Name := 'X';

  // Initialize all properties

  Self.Pos     := pPos;
  Self.State   := stRunning;
  Self.Food    := BaseStartFood;

  Self.Pref := pPref;
end;
//------------------------------------------------------------------------------
// Return true if you are alive
//
function TBaseObject.InqState: TBaseState;
begin
  InqState := Self.State;
end;
//------------------------------------------------------------------------------
// Return id
//
function TBaseObject.InqId: integer;
begin
  InqId := Self.Id;
end;
//------------------------------------------------------------------------------
// Return Information about the queen
//
function TBaseObject.InqInfo (w : string): string;
begin
  InqInfo :=
    Self.Name + '[' + IntToStr(Id) + '] W: ' + w +
    ' F: ' + IntToStr(round(Food)) +
    ' P: ' + IntToStr(Pos.x) + ',' + IntToStr(Pos.Y);
end;
//------------------------------------------------------------------------------
// Set new area to be in
//
procedure TBaseObject.SetArea (rArea : TRect);
begin
  Pref.Area := rArea;
end;
//------------------------------------------------------------------------------
// Return position
//
function TBaseObject.InqPos: TPoint;
begin
  InqPos := Self.Pos;
end;
//------------------------------------------------------------------------------
// Return radius
//
function TBaseObject.InqRad: integer;
begin
  if Self.Food < 8 then
    InqRad := round(Self.Food)
  else
    InqRad := round(SQRT(Self.Food));
end;
//------------------------------------------------------------------------------
// Return amount of food
//
function TBaseObject.InqFood: real;
begin
  InqFood := Self.Food;
end;
//------------------------------------------------------------------------------
// Feed sombody some of your food
//
function TBaseObject.Feed (pObj : TBaseObject): real ;
var
  fFood : real;
begin
  Feed := 0;

  if pObj <> nil then
    begin
      // Decide how much to give away (not more than you got)

      fFood := Min (BaseFeedFood, Self.Food);

      // Tell the other object to eat it (return what he eat)

      fFood := pObj.Eat(fFood);

      // Decrease your own food

      Self.Food := Self.Food - fFood;

      // Tell about it

      if Self.DebugOn then
        Pref.Debug.Items.Add(InqInfo('Feed'));

      Feed := fFood;
    end;
end;
//------------------------------------------------------------------------------
// Accept the food
//
function TBaseObject.Eat (fFood : real): real;
begin

  // We are just hapy to get what we get

  Self.Food := Self.Food + fFood;

  // Tell about it

  if Self.DebugOn then
    Pref.Debug.Items.Add(InqInfo('Eat'));

  Eat := fFood;
end;
//------------------------------------------------------------------------------
// Accept beeing robbed
//
function TBaseObject.Rob (fFood : real) : real;
var
  fLost : real;
begin

  // We give all what we got if asked for

  fLost := Min (fFood, Self.Food);
  Self.Food := Self.Food - fLost;

  // Tell about it

  if Self.DebugOn then
    Pref.Debug.Items.Add(InqInfo('Ate'));

  Rob := fLost;
end;
//------------------------------------------------------------------------------
// Act
//
procedure TBaseObject.Act(bDebug : boolean);
begin
  // Take care of the debug flag

  Self.DebugOn := bDebug;
end;
//------------------------------------------------------------------------------
// Draw
//
procedure TBaseObject.Draw();
var
  wdt : integer;
begin
  // Different color depending on state

  if (Self.State = stDead) then
    Pref.Can.Brush.Color := clBlack
  else
    Pref.Can.Brush.Color := clGreen;

  Pref.Can.Brush.Style := bsSolid;
  Pref.Can.Pen.Color   := clBlack;
  Pref.Can.Pen.Width   := 1;
  Pref.Can.Pen.Style   := psSolid;

  // Calc how big the objects should be

  wdt := round(Self.Food);
  Pref.Can.Ellipse(pos.X - wdt, pos.Y - wdt, pos.X + wdt, pos.Y + wdt);
end;
end.
