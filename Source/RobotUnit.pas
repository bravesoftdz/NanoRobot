unit RobotUnit;

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

  PrefUnit,
  BaseUnit,     // Base object
  ScentUnit;    // Scent units

const
  RobotStartFood    = 5.0;    // Start food from birth
  RobotMaxLoad      = 10.0;   // Max food you can carry
  RobotScentIterNr  = 9;      // How often you place a scent dropping
  RobotEat          = 0.001;  // How much a robot eat for him slef by walking around
  RobotMaxHappiness = 200000; // Maximum happiness a robot can have

type
  TRealPos = record
    X : Real;
    Y : Real;
  end;

type TRobotState = (rstLookForFood, rstLookForQueen);

type TRobot = class(TBaseObject)
  private
    CurPos             : TRealPos;     // Current position
    InternalState      : TRobotState;  // Internal state
    FoodLeft           : integer;      // Amount of food left when just eaten
    Happiness          : integer;      // Amount of happiness
    OnTrack            : boolean;      // True if following a track
    OnTrackLastScentId : integer;
    OnTrackLastValue   : integer;      // Last Happiness value if on track
    OnTrackLastValueNr : integer;      // Number of times on this value
    Angle              : real;         // Direction robot is walking
    ScentIter          : integer;      // Iteration for dropping scent
  public

    //-------------  constructors / destructors and such -----------------------

    constructor Create(pPos : TPoint; pPref  : TPref ); override;

    procedure Act (bDebug : boolean); override;
    function  InqPos : TPoint; override;

    // Return info about this object

    function InqInfo (w : string): string; override;

    procedure Draw (); override;
  private

    //---- Private functions ---------------------------------------------------

    // Find any food if you need it and eat (return true if you are eating)

    function  IsFoodHere  : boolean;

    // FInd the queen if you have food to spare (return true if you are feeding)

    function  IsQueenHere : boolean;

    // Find out if you have gone wild (return true if you did)

    function  IsOutsideWorld (rArea : TRect) : boolean;

    // Find the direction too the queen

    function  FindQueen : boolean ;

    // Find the direction too some food

    function  FindFood : boolean ;

    // Leave a scent for others to trip in

    procedure DropScent (bForce : boolean);

    // Find out if this object is a scent and has volume
    // and is of the type you need

    function InqVolumeFromScent
            (ThisObject : TObject;   // Scent object to investigate
             ScentType  : TScentType // Type of scent to look for
            ): boolean;

    // Find nearest scent of a certain type

    function FindNearestScent (ScentType : TScentType) : TScent;
  end;

  //--- General geometrical function -------------------------------------------

  function InqAng (pm,pe : TPoint) : real;
  function PntRotate (m, p : TPoint; ang : real) : TPoint;
  function IsPntOnPnt (pa,pb : TPoint; D : integer) : boolean; overload ;
implementation

uses
  QueenUnit,
  FoodUnit;

constructor TRobot.Create(pPos : TPoint; pPref  : TPref );
begin
  Self.Name := 'R';

  inherited;

  Self.InternalState := rstLookForFood;

  Self.CurPos.X := pPos.X;
  Self.CurPos.Y := pPos.Y;

  Self.Food     := RobotStartFood;
  Self.FoodLeft := 0;

  Self.Angle := Random(round(100 * 2 * pi))/100;

  // From start we are very happy (All babies are)

  Self.Happiness := RobotMaxHappiness;

  Self.OnTrack          := false;
  Self.OnTrackLastValue := 0;
  OnTrackLastScentId    := 0;

  Self.ScentIter := RobotScentIterNr;

  Pref.Debug.Items.Add(InqInfo('Created'))
end;
//------------------------------------------------------------------------------
// Return Information about the queen
//
function TRobot.InqInfo (w : string): string;
var
  s : string;
begin
  s := 'R[' + IntToStr(Id) + '] W:' + w +
    ' F: ' + IntToStr(round(Food)) +
    ' P: ' + IntToStr(round(CurPos.X)) + ',' + IntToStr(round(CurPos.Y)) +
    ' H: ' + IntToStr(Happiness) + ' A: ' + IntToStr(Round((360 * Angle) / (2 * pi)));

  if OnTrack then
    s := s + ' +T'
  else
    s := s + ' -T';

  Case InternalState of
    rstLookForFood  : s := s + ' LF';
    rstLookForQueen : s := s + ' LQ';
  end;

  InqInfo := s;
end;
//------------------------------------------------------------------------------
// Return position
//
function TRobot.InqPos : TPoint;
begin
  InqPos.X := round(Self.CurPos.X);
  InqPos.Y := round(Self.CurPos.Y);
end;
//------------------------------------------------------------------------------
// If food is needed look for it at the place you are right now
//
function TRobot.IsFoodHere : boolean;
var
  i : integer;
  t : TObject;
  p : TPoint;
  f : real;
  fFoundFood : real;

begin
  IsFoodHere := false;

  // Need any food ?

  if Self.InternalState = rstLookForFood then
    begin
      // Walk all food objects

      for i := 0 to Pref.World.Count - 1 do
        begin
          t := Pref.World.Items[i];
          if t <> nil then
            if (t is TFood) then
              begin
                // This is a food object, try if near enough
                // The amount of food it contains is also the radius of it

                p := TFood(t).InqPos();
                f := TFood(t).InqRad();

                if IsPntOnPnt(p,Self.InqPos(), round(f + Self.Food)) then
                  begin
                    // Rob the food object of just a nibble
                    // (as long as you can carry any more food)

                    if Self.Food < RobotMaxLoad then
                      begin

                        // First place a scent right where you are now
                        // That still doesnt contain any food

                        Self.DropScent(true);

                        // The go to the middle of food

                        Self.CurPos.X := p.X;
                        Self.CurPos.Y := p.Y;

                        // Drop a new scent withot food

                        Self.DropScent(true);

                        // Take all you can load from food unit

                        fFoundFood := TFood(t).Rob(RobotMaxLoad - Self.Food + 1);
                        Self.Food := Self.Food + fFoundFood;

                        // Remember how much food left

                        Self.FoodLeft := trunc(TFood(t).InqFood());

                        if DebugOn then Pref.Debug.Items.Add(InqInfo('Ate'));

                        // All that has eaten is happy

                        Self.Happiness := RobotMaxHappiness;

                        // Drop a new scent with food this time

                        Self.DropScent(true);

                        // Reverse angle

                        Self.Angle := Self.Angle + Pi;

                        // Restart tracking

                        Self.OnTrack            := false;
                        Self.OnTrackLastValue   := 0;
                        Self.OnTrackLastValueNr := 0;

                        IsFoodHere := true;
                        break;
                      end
                  end
              end
        end
    end
end;
//------------------------------------------------------------------------------
// If food is needed look for it at this place
//
function TRobot.IsQueenHere : boolean;
var
  i : integer;
  t : TObject;
  p : TPoint;
  f : real;
begin
  IsQueenHere := false;

  // Walk all queen objects

  for i := 0 to Pref.World.Count - 1 do
    begin
      t := Pref.World.Items[i];
      if t <> nil then
        begin
          t := Pref.World.Items[i];
          if t <> nil then
            if (t is TQueen) then
              begin
                p := TQueen(t).InqPos();
                f := TQueen(t).InqRad();

                if IsPntOnPnt(p,Self.InqPos(), round(f + Self.Food)) then
                  begin
                    // If you have food give it to the queen

                    if (Self.InternalState = rstLookForQueen) then
                      begin

                        // First place a scent right where you are now

                        Self.DropScent(true);

                        // Give you whole load

                        f := TQueen(t).Eat(trunc(Self.Food - RobotStartFood + 1));
                        Self.Food := Self.Food - f;
                        if DebugOn then Pref.Debug.Items.Add(InqInfo('Feed'));

                        // Restart tracking

                        Self.OnTrack            := false;
                        Self.OnTrackLastValue   := 0;
                        Self.OnTrackLastValueNr := 0;

                        // Drop a scent here

                        Self.Happiness := RobotMaxHappiness;
                        Self.DropScent(true);

                        // Reverse angle

                        Self.Angle := Self.Angle + Pi;
                      end
                    else
                      begin
                        // So I have seen the queen anyway, Im happy

                        Self.Happiness := RobotMaxHappiness;
                        Self.DropScent(true)
                      end;

                    Exit;
                  end;
              end;
        end;
    end;
end;
//------------------------------------------------------------------------------
//  Make sure the robot doesent walk on the wild side
//
function TRobot.IsOutsideWorld (rArea : TRect) : boolean;
const
  pSafty = 10;
var
  bOut : boolean;
begin
  bOut := false;

  if (Self.CurPos.X < rArea.Left + pSafty) then
    begin
      Self.CurPos.X := rArea.Left + pSafty + 2;
      bOut := true;
    end;

  if (Self.CurPos.X > rArea.Right - pSafty) then
    begin
      Self.CurPos.X := rArea.Right - pSafty - 2;
      bOut := true;
    end;

  if (Self.CurPos.Y < rArea.Top + pSafty) then
    begin
      Self.CurPos.Y := rArea.Top + pSafty + 2;
      bOut := true;
    end;

  if (Self.CurPos.Y > rArea.Bottom - pSafty) then
    begin
      Self.CurPos.Y := rArea.Bottom - pSafty - 2;
      bOut := true;
    end;

  // If outside initiate a new way to go in

  if bOut then
    Angle := Random(round(100 * 2 * pi))/100;

  IsOutsideWorld := bOut;
end;
//------------------------------------------------------------------------------
//  Fid nearest scent of a specified type
//
function TRobot.FindNearestScent (ScentType : TScentType) : TScent;
var
  i             : integer;
  ThisObject    : TBaseObject;
  MaxObject     : TScent;
  MaxHappiness  : integer;
  ThisHappiness : integer;
begin
  // Look for a scent within sniffing distance
  // that does not contain any food scent

  MaxObject    := nil;
  MaxHappiness := 0;

  // Walk all scents whithin distance

  for i := 0 to Pref.World.Count - 1 do
    begin
      ThisObject := Pref.World.Items[i];

      // Find out if this a scent, within distance and its volume
      // And the right type of scent

      if InqVolumeFromScent(ThisObject, ScentType) then
        begin
          // If first scent just take it
          // Remember the happiness of the robot that dropped scent

          ThisHappiness := TScent(ThisObject).InqHappiness();

          if MaxObject = nil then
            begin
              MaxObject    := TScent(ThisObject);
              MaxHappiness := ThisHappiness;
            end
          else
            begin
              // If not first, compare and take the happiest one

              if ThisHappiness > MaxHappiness then
                begin
                  MaxObject    := TScent(ThisObject);
                  MaxHappiness := ThisHappiness;
                end
            end
        end
    end;
  FindNearestScent := MaxObject;
end;
//------------------------------------------------------------------------------
//  Is this a scent and whithin distance, then return if it got volume
//  ScentType holds info on what type of scent we are looking for
//
function TRobot.InqVolumeFromScent
            (ThisObject : TObject; ScentType  : TScentType): boolean;
var
  ThisPos    : TPoint;
  ThisVolume : real;
begin
  InqVolumeFromScent := false;

  // First test for nil

  if ThisObject <> nil then

    // Then test for TScent object

    if (ThisObject is TScent) then

      // Now test if this a scent made by a robot and the scent is
      // of the right kind

      if (ScentType in Tscent(ThisObject).InqScentType()) then
        begin
          // Get position and scent volume

          ThisPos    := TScent(ThisObject).InqPos();
          ThisVolume := TScent(ThisObject).InqVolume();

          // Test if within sniffing range

          if IsPntOnPnt(ThisPos,Self.InqPos(), round(3 * ThisVolume)) then
            InqVolumeFromScent := true;
        end;
end;
//------------------------------------------------------------------------------
//  Find a way home to the queen
//
function TRobot.FindQueen : boolean;
var
  NearestScent  : TScent;
  Pos           : TPoint;
  NewAngle      : real;
begin
  FindQueen := false;

  // Do we look for the queen

  if Self.InternalState = rstLookForQueen then
    begin
      // Look for a scent within sniffing distance
      // that does not contain any food scent

      NearestScent := FindNearestScent(stQueen);

      // Did we find any scent

      NewAngle := Self.Angle;
      if NearestScent <> nil then
        begin

          // Now we use current pos + FoundPos to take out new direction

          Pos := NearestScent.InqPos();

          // Calc the new angle

          NewAngle := InqAng(Self.InqPos(),Pos);

          // If this angle is almost opposite then we just stepped over
          // the scent leading us forward and no better scent was in sight
          // so we dont take, just follow along in the path we have now

          if (OnTrackLastScentId = NearestScent.InqRobotId) and
             (abs(NewAngle - Self.Angle) > (pi * 0.8)) then
            NearestScent := nil;
        end;

      if NearestScent <> nil then
        begin
          Self.Angle := NewAngle;

          if DebugOn and (not Self.OnTrack) then
            Pref.Debug.Items.Add(InqInfo('fToQ'));

          // Tell everybody you are on track

          Self.OnTrack := true;
          OnTrackLastScentId := NearestScent.InqRobotId;
          FindQueen := true;
        end
      else
        begin
          // You lost track

          if DebugOn and Self.OnTrack then
            Pref.Debug.Items.Add(InqInfo('lToQ'));
          Self.OnTrack := false;
        end;
    end
end;
//------------------------------------------------------------------------------
//  Find the shortest way to any food using scent from other robots with food
//
function TRobot.FindFood : boolean;
var
  NearestScent  : TScent;
  Pos           : TPoint;
  NewAngle      : real;
begin
  FindFood := false;

  // Do we look for food in the first place

  if Self.InternalState = rstLookForFood then
    begin
      // Look for a scent within sniffing distance
      // that does contain food scent

      NearestScent := FindNearestScent(stFood);

      // Did we find any scent

      NewAngle := Self.Angle;
      if NearestScent <> nil then
        begin

          // Now we use current pos + FoundPos to take out new direction

          Pos := NearestScent.InqPos();

          // Calc the new angle

          NewAngle := InqAng(Self.InqPos(),Pos);

          // If this angle is almost opposite then we just stepped over
          // the scent leading us forward and no better scent was in sight
          // so we dont take, just follow along in the path we have now

          if (OnTrackLastScentId = NearestScent.InqRobotId) and
             (abs(NewAngle - Self.Angle) > (pi * 0.8)) then
            NearestScent := nil;
        end;

      if NearestScent <> nil then
        begin
          Self.Angle := NewAngle;

          if DebugOn and (not Self.OnTrack) then
            Pref.Debug.Items.Add(InqInfo('fToF'));

          // Tell everybody you are on track

          Self.OnTrack := true;
          OnTrackLastScentId := NearestScent.InqRobotId;
          FindFood := true;
        end
      else
        begin
          // You lost track

          if DebugOn and Self.OnTrack then
            Pref.Debug.Items.Add(InqInfo('lToF'));

          Self.OnTrack := false;
        end;
    end
end;
//------------------------------------------------------------------------------
//  Drop a scent that tells others how you feel
//
procedure TRobot.DropScent(bForce : boolean);
var
  ThisScent   : TObject;
  ThisPos     : TPoint;
  ThisVolume  : Real;
  bFoundScent : boolean;
  i           : integer;
  ScentType   : TScentType;
begin

  // You only drop scent at certain intervals

  if bForce or (Self.ScentIter > RobotScentIterNr) then
    begin
      Self.ScentIter := 0;
                    
      // Decide what type of scent you should drop and hence look for

      if Self.Food > RobotStartFood then
        ScentType := stFood
      else
        ScentType := stQueen;

      // Look for already placed scents
                        
      bFoundScent := false;
      for i := 0 to Pref.World.Count - 1 do
        begin
          ThisScent := Pref.World.Items[i];
          if ThisScent <> nil then
            if (ThisScent is TScent) then
              begin
                // Get scent

                ThisVolume := TScent(ThisScent).InqVolume();
                ThisPos    := TScent(ThisScent).InqPos();

                // Is there a scent here before

                if IsPntOnPnt (ThisPos, Self.InqPos(), round(ThisVolume)) then
                  begin
                    // Is it the same type of scent that you should be leaving
                    // Obs not wanting

                    if (ScentType in TScent(ThisScent).InqScentType) then
                      begin
                        bFoundScent := true;

                        // Update this scent's volume

                        if ((ScentType = stFood) and (Self.FoodLeft < 1)) then
                          TScent(ThisScent).IncVolume(ScentSnuffValue)
                        else
                          TScent(ThisScent).IncVolume(ScentIncreaseValue);

                        // Also increase happiness if is bigger this will
                        // lead other robots on the new trail

                        TScent(ThisScent).SetHappiness(Self.Happiness);
                      end
                  end;
              end;
        end;

      // Found any scent

      if not bFoundScent then
        begin

          // Create a new scent object and return a pointer to it

          Pref.World.Add(TScent.Create(Self.Id, Self.InqPos(),
                      ScentType, Self.FoodLeft, Self.Happiness, Pref));
        end
    end;

  // Add another turn in life

  Self.ScentIter := Self.ScentIter + 1;
end;
//------------------------------------------------------------------------------
//  Act
//
procedure TRobot.Act (bDebug : boolean);
var
  p     : TPoint;
  pNext : TPoint;
begin
  inherited;

  // Behave like a robot, wander about feeling absolutely nothing

  if Self.State <> stDead then
    begin

      // Decide if you are looking for food or queen

      if Self.Food > RobotStartFood then
        Self.InternalState := rstLookForQueen
      else
        Self.InternalState := rstLookForFood;

      // We look for food, even if we really dont want any

      if IsFoodHere() then
        Exit;

      // We also look for queen, even if we dont want any

      if IsQueenHere() then
        Exit;

      // A robot cant go outside the world

      if IsOutsideWorld (Pref.Area) then
        Exit;

      // Try to find what you are looking for

      case Self.InternalState of
        rstLookForFood  : FindFood();
        rstLookForQueen : FindQueen();
      end;

      // Walk the next step in life

      p.X := 0;
      p.Y := 0;
      pNext.X := p.X + 100;
      pNext.Y := 0;
      p := PntRotate(p, pNext, Self.Angle);

      Self.CurPos.X := Self.CurPos.X + (p.X / 50);
      Self.CurPos.Y := Self.CurPos.Y + (p.Y / 50);

      // As live goes along you get sader each step you take

      Self.Happiness := Self.Happiness - 1;

      // Randomize the movement a little bit

      if Self.Food <= 6 then
        Self.Angle := Self.Angle + ((Random(100) - 50) / 1000);

      // Drop a scent now and then

      Self.DropScent (false);

      // A robot must also eat, if no more food left you die

      if Self.Food > 1 then
        Self.Food := Self.Food - RobotEat
      else
        begin
          Self.State := stDead;
          Pref.Debug.Items.Add(InqInfo('Died'))
        end
    end;
end;

procedure TRobot.Draw();
var
  wdt : integer;
begin
  // Different color depending on state

  if (Self.State = stDead) then
    Pref.Can.Brush.Color := clBlack
  else
    begin
      if (Self.Food > RobotStartFood) then
        Pref.Can.Brush.Color := clGreen
      else
        Pref.Can.Brush.Color := clYellow;
    end;

  Pref.Can.Brush.Style := bsSolid;
  Pref.Can.Pen.Color := clBlack;
  Pref.Can.Pen.Width := 1;
  Pref.Can.Pen.Style := psSolid;

  // Calc how big the object should be

  wdt := Max(4,InqRad());
  Pref.Can.Ellipse(round(CurPos.X) - wdt, round(CurPos.Y) - wdt,
                   round(CurPos.X) + wdt, round(CurPos.Y) + wdt);
end;

//------------------------------------------------------------------------------
// find angle on a line between pm (middle) and pe (external)
//
function InqAng (pm,pe : TPoint) : real;
begin
  if (pe.X <> pm.X) then
    InqAng := ArcTan2(pm.Y - pe.Y, pe.X - pm.X)
  else
    if pe.Y < pm.Y then
      InqAng := pi/2
    else if pe.Y > pm.Y then
      InqAng := -pi/2
    else
      InqAng := 0.0;
end; 
//------------------------------------------------------------------------------
// Rotate a point (p) around a another point (m)
//
function PntRotate (m, p : TPoint; ang : real) : TPoint;
var
  dx, dy : integer;
begin

  dx := p.X - m.X;
  dy := p.Y - m.Y;

  PntRotate.X := m.X + round(dx * cos(ang) + dy * sin(ang));
  PntRotate.Y := m.Y + round(dy * cos(ang) - dx * sin(ang));
end;
//------------------------------------------------------------------------------
// Calculate if a point (XA,YA) is on a given point (XB,YB)
// within the Distant D  (rect, not round)
//
function IsPntOnPnt (pa,pb : TPoint; D : integer) : boolean;
begin
  IsPntOnPnt := ((pa.X + D) > pb.X) and
              ((pa.X - D) < pb.X) and
              ((pa.Y + D) > pb.Y) and
              ((pa.Y - D) < pb.Y);
end;
end.

