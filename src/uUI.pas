unit uUI;

{ Warna tema (gaya Binance) dan tombol datar custom-draw }

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, ExtCtrls, StdCtrls;

var
  clrBg, clrPanel, clrPanel2, clrBorder, clrText, clrMuted,
  clrYellow, clrGreen, clrRed, clrGreenDim, clrRedDim, clrBlue, clrGold: TColor;

type
  TFlatBtn = class(TCustomControl)
  private
    FDown, FHover: Boolean;
    FBg, FBgDown, FFg, FFgDown: TColor;
    FBold: Boolean;
    FFontSize: Integer;
    procedure SetDown(V: Boolean);
    procedure CMMouseEnter(var M: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var M: TMessage); message CM_MOUSELEAVE;
    procedure CMTextChanged(var M: TMessage); message CM_TEXTCHANGED;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Down: Boolean read FDown write SetDown;
    property Bg: TColor read FBg write FBg;
    property BgDown: TColor read FBgDown write FBgDown;
    property Fg: TColor read FFg write FFg;
    property FgDown: TColor read FFgDown write FFgDown;
    property Bold: Boolean read FBold write FBold;
    property FontSize: Integer read FFontSize write FFontSize;
    property Caption;
    property OnClick;
  end;

function MakeBtn(AParent: TWinControl; const ACaption: string; X, Y, W, H: Integer;
  AClick: TNotifyEvent; ATag: Integer = 0): TFlatBtn;
function MakePanel(AParent: TWinControl; AAlign: TAlign; ASize: Integer; AColor: TColor): TPanel;
function MakeLabel(AParent: TWinControl; const ACaption: string; X, Y: Integer;
  AColor: TColor; ASize: Integer = 9; ABold: Boolean = False): TLabel;

implementation

constructor TFlatBtn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csClickEvents, csCaptureMouse] - [csDoubleClicks];
  FBg := clrPanel2;
  FBgDown := clrYellow;
  FFg := clrText;
  FFgDown := clrBg;
  FFontSize := 8;
  Width := 60;
  Height := 24;
  Cursor := crHandPoint;
end;

procedure TFlatBtn.SetDown(V: Boolean);
begin
  if FDown <> V then
  begin
    FDown := V;
    Invalidate;
  end;
end;

procedure TFlatBtn.CMMouseEnter(var M: TMessage);
begin
  FHover := True;
  Invalidate;
end;

procedure TFlatBtn.CMMouseLeave(var M: TMessage);
begin
  FHover := False;
  Invalidate;
end;

procedure TFlatBtn.CMTextChanged(var M: TMessage);
begin
  Invalidate;
end;

function Lighten(C: TColor; D: Integer): TColor;
var r, g, b: Integer;
begin
  C := ColorToRGB(C);
  r := GetRValue(C) + D; if r > 255 then r := 255;
  g := GetGValue(C) + D; if g > 255 then g := 255;
  b := GetBValue(C) + D; if b > 255 then b := 255;
  Result := RGB(r, g, b);
end;

procedure TFlatBtn.Paint;
var R: TRect; bgc, fgc: TColor;
begin
  R := ClientRect;
  if FDown then begin bgc := FBgDown; fgc := FFgDown; end
  else begin bgc := FBg; fgc := FFg; end;
  if FHover then bgc := Lighten(bgc, 18);
  Canvas.Brush.Color := bgc;
  Canvas.Pen.Color := Lighten(bgc, 25);
  Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := FFontSize;
  Canvas.Font.Color := fgc;
  if FBold or FDown then Canvas.Font.Style := [fsBold] else Canvas.Font.Style := [];
  DrawText(Canvas.Handle, PChar(Caption), -1, R, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

function MakeBtn(AParent: TWinControl; const ACaption: string; X, Y, W, H: Integer;
  AClick: TNotifyEvent; ATag: Integer): TFlatBtn;
begin
  Result := TFlatBtn.Create(AParent);
  Result.Parent := AParent;
  Result.SetBounds(X, Y, W, H);
  Result.Caption := ACaption;
  Result.OnClick := AClick;
  Result.Tag := ATag;
end;

function MakePanel(AParent: TWinControl; AAlign: TAlign; ASize: Integer; AColor: TColor): TPanel;
begin
  Result := TPanel.Create(AParent);
  Result.Parent := AParent;
  Result.BevelOuter := bvNone;
  Result.Color := AColor;
  Result.ParentBackground := False;
  Result.Align := AAlign;
  if AAlign in [alTop, alBottom] then Result.Height := ASize
  else if AAlign in [alLeft, alRight] then Result.Width := ASize;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Color := clrText;
end;

function MakeLabel(AParent: TWinControl; const ACaption: string; X, Y: Integer;
  AColor: TColor; ASize: Integer; ABold: Boolean): TLabel;
begin
  Result := TLabel.Create(AParent);
  Result.Parent := AParent;
  Result.Left := X;
  Result.Top := Y;
  Result.Caption := ACaption;
  Result.Transparent := True;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := ASize;
  Result.Font.Color := AColor;
  if ABold then Result.Font.Style := [fsBold];
end;

initialization
  clrBg := RGB(11, 14, 17);
  clrPanel := RGB(24, 26, 32);
  clrPanel2 := RGB(30, 35, 41);
  clrBorder := RGB(43, 49, 57);
  clrText := RGB(234, 236, 239);
  clrMuted := RGB(132, 142, 156);
  clrYellow := RGB(240, 185, 11);
  clrGreen := RGB(14, 203, 129);
  clrRed := RGB(246, 70, 93);
  clrGreenDim := RGB(10, 92, 62);
  clrRedDim := RGB(118, 36, 48);
  clrBlue := RGB(41, 121, 255);
  clrGold := RGB(212, 175, 55);
end.
