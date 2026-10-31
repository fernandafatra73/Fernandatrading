unit uChart;

{ Grafik candlestick custom (double-buffer) :
  - geser kiri/kanan (drag), zoom waktu (scroll / drag sumbu waktu)
  - zoom harga atas/bawah (drag sumbu harga / Ctrl+scroll), geser vertikal saat skala manual
  - MA 9/25/99/200/500/700, Bollinger Band, S1-S3 / R1-R3, BOS/CHoCH, FVG, pola candle, volume }

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Math, uData, uUI;

type
  { posisi MT5 yang sedang terbuka (garis kuning di grafik) }
  TPosLine = record
    Price: Double;
    Lbl: string;
  end;
  TPosLines = array of TPosLine;

  TChartView = class(TCustomControl)
  private
    FBmp: TBitmap;
    FBarW, FScroll: Double;
    FAuto: Boolean;
    FPMin, FPMax: Double;
    FMX, FMY: Integer;
    FMouseIn: Boolean;
    FDrag: Integer;
    FDX, FDY: Integer;
    FDScroll, FDPMin, FDPMax, FDBarW: Double;
    FPlot, FVol: TRect;
    FLo, FHi: Double;
    FAxisW, FTimeH: Integer;
    procedure WMEraseBkgnd(var M: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure CMMouseLeave(var M: TMessage); message CM_MOUSELEAVE;
    function XOf(i: Double): Integer;
    function YOf(p: Double): Integer;
    function PriceAt(y: Integer): Double;
    function IdxAt(x: Integer): Integer;
    function VisBars: Double;
    procedure ClampScroll;
    procedure DrawLine(cv: TCanvas; const Arr: TDArr; i0, i1: Integer; Col: TColor; W: Integer);
    procedure HLine(cv: TCanvas; P: Double; Col: TColor; const Lbl: string; Style: TPenStyle);
    procedure AxisTag(cv: TCanvas; P: Double; Bg, Fg: TColor; const Extra: string);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
  public
    C: TCandles;
    MA: array[0..5] of TDArr;
    BBU, BBM, BBL: TDArr;
    Events: TStructEvts;
    FVGs: TFVGs;
    Marks: TPatMarks;
    Piv: TPivots;
    ShowMA: array[0..5] of Boolean;
    ShowBB, ShowSR, ShowSMC, ShowFVG, ShowPat, ShowVol: Boolean;
    SigAction: Integer;
    SigEntry, SigSL, SigTP1, SigTP2: Double;
    Digits, TFSec: Integer;
    Title: string;
    LocalOffH: Double;
    PendPrice: Double;   { garis hijau harga pending dari panel OPEN (0 = tidak ada) }
    PendLbl: string;
    PosLines: TPosLines;   { garis kuning posisi BUY / SELL yang sedang terbuka }
    PLText, PLCap: string;   { untung / rugi MT5 besar di kanan bawah grafik ('' = tidak tampil) }
    PLColor: TColor;
    ModalText: string;   { modal / balance MT5, kuning di kiri bawah grafik ('' = tidak tampil) }
    BgColor, GridColor, BandColor, TitleColor, FvgColor, FvgPen: TColor;   { warna belakang grafik (tab Edukasi) }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Wheel(Delta: Integer; Shift: TShiftState);
    procedure ZoomIn;
    procedure ZoomOut;
    procedure ResetView;
    procedure Snapshot(B: TBitmap);
    procedure SetBg(Idx: Integer);
  end;

const
  ChartBgNames: array[0..5] of string = ('Standar (warna sekarang)', 'Biru', 'Hijau', 'Putih', 'Ungu', 'Abu-abu');

var
  MAColors: array[0..5] of TColor;

implementation

const
  PadTop = 46;

constructor TChartView.Create(AOwner: TComponent);
var i: Integer;
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  FBmp := TBitmap.Create;
  FBarW := 7; FScroll := -6; FAuto := True;
  FAxisW := 80; FTimeH := 22;
  for i := 0 to 5 do ShowMA[i] := True;
  ShowBB := True; ShowSR := True; ShowSMC := True; ShowFVG := True; ShowPat := True; ShowVol := True;
  Digits := 2; TFSec := 3600;
  Cursor := crCross;
  SetBg(0);
end;

{ warna belakang, grid, area Bollinger & judul untuk tiap pilihan ChartBgNames }
procedure TChartView.SetBg(Idx: Integer);
begin
  { FVG abu-abu; arah tetap terlihat dari tulisan FVG hijau / merah }
  TitleColor := clrYellow; FvgColor := RGB(58, 62, 70); FvgPen := RGB(96, 102, 112);
  case Idx of
    1: begin BgColor := RGB(10, 22, 48); GridColor := RGB(24, 40, 72); BandColor := RGB(22, 30, 66); end;
    2: begin BgColor := RGB(8, 32, 22); GridColor := RGB(20, 52, 38); BandColor := RGB(18, 40, 40); end;
    3: begin
         BgColor := RGB(255, 255, 255); GridColor := RGB(228, 231, 236); BandColor := RGB(238, 232, 250);
         TitleColor := RGB(170, 120, 0); FvgColor := RGB(214, 217, 223); FvgPen := RGB(160, 165, 175);
       end;
    4: begin BgColor := RGB(30, 14, 44); GridColor := RGB(48, 30, 66); BandColor := RGB(44, 24, 64); end;
    5: begin
         BgColor := RGB(44, 48, 54); GridColor := RGB(60, 65, 72); BandColor := RGB(54, 52, 68);
         FvgColor := RGB(82, 87, 96); FvgPen := RGB(120, 126, 136);
       end;
  else
    BgColor := clrBg; GridColor := RGB(26, 30, 36); BandColor := RGB(20, 17, 33);
  end;
  Invalidate;
end;

destructor TChartView.Destroy;
begin
  FBmp.Free;
  inherited;
end;

procedure TChartView.Snapshot(B: TBitmap);
var keep: Boolean;
begin
  { gambar ulang tanpa crosshair mouse, lalu salin buffer }
  keep := FMouseIn;
  FMouseIn := False;
  Paint;
  FMouseIn := keep;
  B.Assign(FBmp);
end;

procedure TChartView.WMEraseBkgnd(var M: TWMEraseBkgnd);
begin
  M.Result := 1;
end;

procedure TChartView.CMMouseLeave(var M: TMessage);
begin
  FMouseIn := False;
  Invalidate;
end;

function TChartView.VisBars: Double;
begin
  Result := (FPlot.Right - FPlot.Left) / FBarW;
end;

procedure TChartView.ClampScroll;
var n: Integer;
begin
  n := Length(C);
  if FScroll < -VisBars * 0.7 then FScroll := -VisBars * 0.7;
  if FScroll > n - 10 then FScroll := n - 10;
end;

function TChartView.XOf(i: Double): Integer;
begin
  Result := FPlot.Right - Round((Length(C) - 1 - FScroll - i + 0.5) * FBarW);
end;

function TChartView.YOf(p: Double): Integer;
begin
  if FHi <= FLo then begin Result := FPlot.Top; Exit; end;
  Result := FPlot.Top + PadTop + Round((FHi - p) / (FHi - FLo) * (FPlot.Bottom - FPlot.Top - PadTop - 8));
end;

function TChartView.PriceAt(y: Integer): Double;
begin
  Result := FHi - (y - FPlot.Top - PadTop) / (FPlot.Bottom - FPlot.Top - PadTop - 8) * (FHi - FLo);
end;

function TChartView.IdxAt(x: Integer): Integer;
begin
  Result := Round(Length(C) - 1 - FScroll - (FPlot.Right - x) / FBarW + 0.5);
end;

function CountdownS(Sec: Double): string;
var t: Int64;
begin
  if Sec < 0 then Sec := 0;
  t := Round(Sec);
  if t >= 3600 then Result := Format('%.2d:%.2d:%.2d', [t div 3600, (t mod 3600) div 60, t mod 60])
  else Result := Format('%.2d:%.2d', [t div 60, t mod 60]);
end;

function NiceStep(R: Double): Double;
var e, f: Double;
begin
  if R <= 0 then begin Result := 1; Exit; end;
  e := Power(10, Floor(Log10(R)));
  f := R / e;
  if f < 1.5 then Result := e
  else if f < 3 then Result := 2 * e
  else if f < 7 then Result := 5 * e
  else Result := 10 * e;
end;

procedure TChartView.DrawLine(cv: TCanvas; const Arr: TDArr; i0, i1: Integer; Col: TColor; W: Integer);
var i: Integer; started: Boolean;
begin
  if Length(Arr) <> Length(C) then Exit;
  cv.Pen.Color := Col; cv.Pen.Width := W; cv.Pen.Style := psSolid;
  started := False;
  for i := i0 to i1 do
  begin
    if Arr[i] <= 0 then begin started := False; Continue; end;
    if not started then begin cv.MoveTo(XOf(i), YOf(Arr[i])); started := True; end
    else cv.LineTo(XOf(i), YOf(Arr[i]));
  end;
  cv.Pen.Width := 1;
end;

procedure TChartView.HLine(cv: TCanvas; P: Double; Col: TColor; const Lbl: string; Style: TPenStyle);
var y: Integer;
begin
  if (P < FLo) or (P > FHi) then Exit;
  y := YOf(P);
  cv.Pen.Color := Col; cv.Pen.Style := Style; cv.Pen.Width := 1;
  cv.MoveTo(FPlot.Left, y); cv.LineTo(FPlot.Right, y);
  cv.Pen.Style := psSolid;
  if Lbl <> '' then
  begin
    cv.Brush.Style := bsClear;
    cv.Font.Color := Col; cv.Font.Style := [fsBold];
    cv.TextOut(FPlot.Right - cv.TextWidth(Lbl) - 6, y - cv.TextHeight(Lbl) - 1, Lbl);
    cv.Font.Style := [];
  end;
end;

procedure TChartView.AxisTag(cv: TCanvas; P: Double; Bg, Fg: TColor; const Extra: string);
var y, h: Integer; R: TRect;
begin
  if (P < FLo) or (P > FHi) then Exit;
  y := YOf(P);
  if Extra <> '' then h := 30 else h := 16;
  R := Rect(FPlot.Right + 1, y - 8, ClientWidth, y - 8 + h);
  cv.Brush.Style := bsSolid; cv.Brush.Color := Bg; cv.FillRect(R);
  cv.Brush.Style := bsClear; cv.Font.Color := Fg;
  cv.TextOut(R.Left + 4, R.Top + 1, FmtP(P, Digits));
  if Extra <> '' then cv.TextOut(R.Left + 4, R.Top + 15, Extra);
end;

procedure TChartView.Paint;
var
  cv: TCanvas; n, i, i0, i1, x, y, yo, yc, bw, k, step, w, h: Integer;
  p, ps, vmax, last: Double; col: TColor; dt: TDateTime; s: string;
  pts: array of TPoint; hv: Integer; R: TRect; pm: TPatMark;
  tagY: array[0..5] of Integer; nTag, j, m: Integer; moved: Boolean;
begin
  w := ClientWidth; h := ClientHeight;
  if (FBmp.Width <> w) or (FBmp.Height <> h) then begin FBmp.Width := w; FBmp.Height := h; end;
  cv := FBmp.Canvas;
  cv.Font.Name := 'Segoe UI'; cv.Font.Size := 8; cv.Font.Style := [];
  cv.Brush.Style := bsSolid; cv.Brush.Color := BgColor;
  cv.FillRect(Rect(0, 0, w, h));
  n := Length(C);

  FPlot := Rect(0, 0, w - FAxisW, h - FTimeH);
  if ShowVol then
  begin
    hv := Round(FPlot.Bottom * 0.17);
    FVol := Rect(0, FPlot.Bottom - hv, FPlot.Right, FPlot.Bottom);
    FPlot.Bottom := FVol.Top - 4;
  end
  else FVol := Rect(0, FPlot.Bottom, FPlot.Right, FPlot.Bottom);

  if n = 0 then
  begin
    cv.Font.Color := clrMuted; cv.Font.Size := 12;
    cv.TextOut(w div 2 - 80, h div 2, 'Memuat data pasar...');
    Canvas.Draw(0, 0, FBmp);
    Exit;
  end;

  i1 := Ceil(n - 1 - FScroll); if i1 > n - 1 then i1 := n - 1;
  i0 := Floor(n - 1 - FScroll - VisBars); if i0 < 0 then i0 := 0;
  if i1 < i0 then i1 := i0;

  { skala harga }
  if FAuto then
  begin
    FLo := C[i0].L; FHi := C[i0].H;
    for i := i0 to i1 do begin FLo := Min(FLo, C[i].L); FHi := Max(FHi, C[i].H); end;
    p := (FHi - FLo) * 0.06; if p = 0 then p := FHi * 0.001;
    FLo := FLo - p; FHi := FHi + p;
  end
  else begin FLo := FPMin; FHi := FPMax; end;

  { grid harga }
  ps := NiceStep((FHi - FLo) / Max(2, (FPlot.Bottom - FPlot.Top) / 55));
  p := Ceil(FLo / ps) * ps;
  cv.Pen.Color := GridColor;
  cv.Brush.Style := bsClear;
  while p < FHi do
  begin
    y := YOf(p);
    if y > FPlot.Top + 10 then
    begin
      cv.MoveTo(0, y); cv.LineTo(FPlot.Right, y);
      cv.Font.Color := clrMuted;
      cv.TextOut(FPlot.Right + 6, y - 7, FmtP(p, Digits));
    end;
    p := p + ps;
  end;

  { grid & label waktu }
  step := Max(1, Ceil(95 / FBarW));
  cv.Pen.Color := GridColor;
  for i := i0 to i1 do
    if (C[i].T div 1000 div TFSec) mod step = 0 then
    begin
      x := XOf(i);
      cv.MoveTo(x, 0); cv.LineTo(x, FVol.Bottom);
      dt := C[i].T / 86400000 + 25569 + LocalOffH / 24;
      if TFSec >= 86400 then s := FormatDateTime('dd mmm yy', dt)
      else if Frac(dt) < (TFSec * step / 86400) then s := FormatDateTime('dd mmm', dt)
      else s := FormatDateTime('hh:nn', dt);
      cv.Font.Color := clrMuted;
      cv.TextOut(x - cv.TextWidth(s) div 2, FVol.Bottom + 4, s);
    end;

  { FVG }
  if ShowFVG then
    for k := 0 to High(FVGs) do
      with FVGs[k] do
      begin
        if (EndIdx <> -1) and ((EndIdx < i0) or (n - 1 - EndIdx > 60)) then Continue;
        if (EndIdx = -1) and (n - 1 - StartIdx > 200) then Continue;
        if EndIdx = -1 then x := FPlot.Right else x := XOf(EndIdx);
        R := Rect(XOf(StartIdx), YOf(Top), x, YOf(Bot));
        if R.Right < 0 then Continue;
        cv.Brush.Color := FvgColor; cv.Pen.Color := FvgPen;
        cv.Brush.Style := bsSolid;
        cv.Rectangle(R.Left, R.Top, R.Right, R.Bottom + 1);
        cv.Brush.Style := bsClear;
        cv.Font.Size := 7;
        if Dir = 1 then cv.Font.Color := clrGreen else cv.Font.Color := clrRed;
        if (R.Bottom - R.Top >= 9) and (R.Right - R.Left > 26) then cv.TextOut(R.Left + 3, R.Top, 'FVG');
        cv.Font.Size := 8;
      end;

  { Bollinger Band }
  if ShowBB and (Length(BBU) = n) then
  begin
    SetLength(pts, 0);
    for i := i0 to i1 do
      if BBU[i] > 0 then begin SetLength(pts, Length(pts) + 1); pts[High(pts)] := Point(XOf(i), YOf(BBU[i])); end;
    for i := i1 downto i0 do
      if BBL[i] > 0 then begin SetLength(pts, Length(pts) + 1); pts[High(pts)] := Point(XOf(i), YOf(BBL[i])); end;
    if Length(pts) > 3 then
    begin
      cv.Brush.Style := bsSolid; cv.Brush.Color := BandColor; cv.Pen.Color := BandColor;
      cv.Polygon(pts);
    end;
    DrawLine(cv, BBU, i0, i1, RGB(149, 117, 205), 1);
    DrawLine(cv, BBL, i0, i1, RGB(149, 117, 205), 1);
    cv.Pen.Style := psDot;
    DrawLine(cv, BBM, i0, i1, RGB(110, 90, 160), 1);
    cv.Pen.Style := psSolid;
  end;

  { Support / Resistance }
  if ShowSR and Piv.Valid then
  begin
    HLine(cv, Piv.R3, RGB(255, 82, 82), 'R3 ' + FmtP(Piv.R3, Digits), psDash);
    HLine(cv, Piv.R2, RGB(255, 120, 120), 'R2 ' + FmtP(Piv.R2, Digits), psDash);
    HLine(cv, Piv.R1, RGB(255, 160, 160), 'R1 ' + FmtP(Piv.R1, Digits), psDash);
    HLine(cv, Piv.P, clrYellow, 'Pivot ' + FmtP(Piv.P, Digits), psDot);
    HLine(cv, Piv.S1, RGB(130, 230, 180), 'S1 ' + FmtP(Piv.S1, Digits), psDash);
    HLine(cv, Piv.S2, RGB(60, 210, 150), 'S2 ' + FmtP(Piv.S2, Digits), psDash);
    HLine(cv, Piv.S3, RGB(0, 180, 110), 'S3 ' + FmtP(Piv.S3, Digits), psDash);
  end;

  { Moving Averages }
  for k := 5 downto 0 do
    if ShowMA[k] then DrawLine(cv, MA[k], i0, i1, MAColors[k], 1 + Ord(k >= 3));

  { Candle }
  bw := Max(1, Round(FBarW * 0.72));
  if (bw > 2) and (bw mod 2 = 0) then Dec(bw);
  for i := i0 to i1 do
  begin
    x := XOf(i);
    if C[i].C >= C[i].O then col := clrGreen else col := clrRed;
    cv.Pen.Color := col; cv.Pen.Style := psSolid;
    cv.MoveTo(x, YOf(C[i].H)); cv.LineTo(x, YOf(C[i].L) + 1);
    yo := YOf(C[i].O); yc := YOf(C[i].C);
    if yo = yc then begin cv.MoveTo(x - bw div 2, yo); cv.LineTo(x + bw div 2 + 1, yo); end
    else
    begin
      cv.Brush.Style := bsSolid; cv.Brush.Color := col;
      cv.FillRect(Rect(x - bw div 2, Min(yo, yc), x - bw div 2 + bw, Max(yo, yc) + 1));
    end;
  end;

  { BOS / CHoCH }
  if ShowSMC then
  begin
    cv.Font.Size := 7;
    for k := 0 to High(Events) do
      with Events[k] do
      begin
        if (ToIdx < i0) or (FromIdx > i1) then Continue;
        if Dir = 1 then col := clrGreen else col := clrRed;
        if Kind = 2 then col := RGB(255, 196, 0);
        y := YOf(Level);
        cv.Pen.Color := col; cv.Pen.Style := psDot;
        cv.MoveTo(XOf(FromIdx), y); cv.LineTo(XOf(ToIdx), y);
        cv.Pen.Style := psSolid;
        if Kind = 2 then s := 'CHoCH' else s := 'BOS';
        cv.Brush.Style := bsClear; cv.Font.Color := col;
        if Kind = 2 then cv.Font.Style := [fsBold] else cv.Font.Style := [];
        x := (XOf(FromIdx) + XOf(ToIdx)) div 2 - cv.TextWidth(s) div 2;
        if Dir = 1 then cv.TextOut(x, y - 12, s) else cv.TextOut(x, y + 1, s);
      end;
    cv.Font.Size := 8; cv.Font.Style := [];
  end;

  { Penanda pola candle }
  if ShowPat and (FBarW >= 4) then
  begin
    cv.Font.Size := 7;
    for k := 0 to High(Marks) do
    begin
      pm := Marks[k];
      if (pm.Idx < i0) or (pm.Idx > i1) or (pm.Dir = 0) then Continue;
      if Pos(' ' + pm.Short + ' ', ' H SS BuE BeE MS ES 3WS 3BC ') = 0 then Continue;
      x := XOf(pm.Idx);
      cv.Brush.Style := bsClear;
      if pm.Dir = 1 then
      begin
        cv.Font.Color := RGB(0, 230, 160);
        y := YOf(C[pm.Idx].L) + 4;
        cv.TextOut(x - cv.TextWidth(pm.Short) div 2, y + 6, pm.Short);
        cv.Pen.Color := RGB(0, 230, 160); cv.Brush.Color := RGB(0, 230, 160); cv.Brush.Style := bsSolid;
        cv.Polygon([Point(x, y), Point(x - 3, y + 5), Point(x + 3, y + 5)]);
      end
      else
      begin
        cv.Font.Color := RGB(255, 120, 140);
        y := YOf(C[pm.Idx].H) - 4;
        cv.TextOut(x - cv.TextWidth(pm.Short) div 2, y - 18, pm.Short);
        cv.Pen.Color := RGB(255, 120, 140); cv.Brush.Color := RGB(255, 120, 140); cv.Brush.Style := bsSolid;
        cv.Polygon([Point(x, y), Point(x - 3, y - 5), Point(x + 3, y - 5)]);
      end;
    end;
    cv.Font.Size := 8;
  end;

  { Rencana sinyal (Entry / SL / TP) }
  if (SigAction <> 0) and (SigEntry > 0) then
  begin
    HLine(cv, SigSL, RGB(255, 60, 60), 'SL ' + FmtP(SigSL, Digits), psDashDot);
    HLine(cv, SigTP1, RGB(0, 255, 170), 'TP1 (1:2) ' + FmtP(SigTP1, Digits), psDashDot);
    HLine(cv, SigTP2, RGB(0, 200, 255), 'TP2 (1:3) ' + FmtP(SigTP2, Digits), psDashDot);
  end;

  { Volume }
  if ShowVol then
  begin
    vmax := 0;
    for i := i0 to i1 do vmax := Max(vmax, C[i].V);
    if vmax > 0 then
      for i := i0 to i1 do
      begin
        x := XOf(i);
        if C[i].C >= C[i].O then cv.Brush.Color := clrGreenDim else cv.Brush.Color := clrRedDim;
        cv.Brush.Style := bsSolid;
        y := FVol.Bottom - Round(C[i].V / vmax * (FVol.Bottom - FVol.Top - 12));
        cv.FillRect(Rect(x - bw div 2, y, x - bw div 2 + bw, FVol.Bottom));
      end;
    cv.Pen.Color := clrBorder;
    cv.MoveTo(0, FVol.Top - 2); cv.LineTo(FPlot.Right, FVol.Top - 2);
    cv.Brush.Style := bsClear; cv.Font.Color := clrMuted;
    cv.TextOut(4, FVol.Top, 'Vol ' + FloatToStrF(C[n - 1].V, ffNumber, 18, 2));
  end;

  { garis harga terakhir }
  last := C[n - 1].C;
  if last >= C[n - 1].O then col := clrGreen else col := clrRed;
  if (last >= FLo) and (last <= FHi) then
  begin
    y := YOf(last);
    cv.Pen.Color := col; cv.Pen.Style := psDot;
    cv.MoveTo(0, y); cv.LineTo(FPlot.Right, y);
    cv.Pen.Style := psSolid;
  end;

  { sumbu }
  cv.Pen.Color := clrBorder;
  cv.MoveTo(FPlot.Right, 0); cv.LineTo(FPlot.Right, h);
  cv.MoveTo(0, FVol.Bottom); cv.LineTo(w, FVol.Bottom);

  if ShowSR and Piv.Valid then
  begin
    AxisTag(cv, Piv.R1, RGB(120, 40, 50), clrText, '');
    AxisTag(cv, Piv.S1, RGB(20, 90, 60), clrText, '');
  end;
  if SigAction <> 0 then
  begin
    AxisTag(cv, SigSL, RGB(170, 30, 40), clrText, '');
    AxisTag(cv, SigTP1, RGB(0, 120, 80), clrText, '');
  end;
  p := (C[n - 1].T div 1000 + TFSec) - (Now - 25569 - LocalOffH / 24) * 86400;
  AxisTag(cv, last, col, clWhite, CountdownS(p));

  { garis kuning: harga open posisi BUY / SELL yang sedang terbuka di MT5 }
  for i := 0 to High(PosLines) do
    with PosLines[i] do
    begin
      if (Price < FLo) or (Price > FHi) then Continue;
      y := YOf(Price);
      cv.Pen.Color := clrYellow; cv.Pen.Width := 2; cv.Pen.Style := psSolid;
      cv.MoveTo(FPlot.Left, y); cv.LineTo(FPlot.Right, y);
      cv.Pen.Width := 1;
      cv.Font.Style := [fsBold];
      R := Rect(FPlot.Right - cv.TextWidth(Lbl) - 20, y - 18, FPlot.Right - 8, y - 2);
      cv.Brush.Style := bsSolid; cv.Brush.Color := clrYellow; cv.FillRect(R);
      cv.Brush.Style := bsClear; cv.Font.Color := clrBg;
      cv.TextOut(R.Left + 6, R.Top + 1, Lbl);
      cv.Font.Style := [];
    end;

  { garis hijau: harga pending yang sedang diatur di panel OPEN }
  if (PendPrice > 0) and (PendPrice >= FLo) and (PendPrice <= FHi) then
  begin
    y := YOf(PendPrice);
    cv.Pen.Color := clrGreen; cv.Pen.Width := 2; cv.Pen.Style := psSolid;
    cv.MoveTo(FPlot.Left, y); cv.LineTo(FPlot.Right, y);
    cv.Pen.Width := 1;
    cv.Font.Style := [fsBold];
    R := Rect(FPlot.Left + 8, y - 18, FPlot.Left + 20 + cv.TextWidth(PendLbl), y - 2);
    cv.Brush.Style := bsSolid; cv.Brush.Color := clrGreen; cv.FillRect(R);
    cv.Brush.Style := bsClear; cv.Font.Color := clWhite;
    cv.TextOut(R.Left + 6, R.Top + 1, PendLbl);
    cv.Font.Style := [];
  end;

  { crosshair }
  k := n - 1;
  if FMouseIn and (FMX < FPlot.Right) and (FMY < FVol.Bottom) then
  begin
    k := IdxAt(FMX);
    if k > n - 1 then k := n - 1;
    if k < 0 then k := 0;
    cv.Pen.Color := RGB(110, 118, 130); cv.Pen.Style := psDot;
    cv.MoveTo(0, FMY); cv.LineTo(FPlot.Right, FMY);
    cv.MoveTo(XOf(k), 0); cv.LineTo(XOf(k), FVol.Bottom);
    cv.Pen.Style := psSolid;
    if FMY < FPlot.Bottom then
    begin
      R := Rect(FPlot.Right + 1, FMY - 8, w, FMY + 8);
      cv.Brush.Style := bsSolid; cv.Brush.Color := RGB(70, 76, 86); cv.FillRect(R);
      cv.Brush.Style := bsClear; cv.Font.Color := clWhite;
      cv.TextOut(R.Left + 4, R.Top + 1, FmtP(PriceAt(FMY), Digits));
    end;
    dt := C[k].T / 86400000 + 25569 + LocalOffH / 24;
    s := FormatDateTime('ddd dd mmm yy  hh:nn', dt);
    x := XOf(k) - cv.TextWidth(s) div 2 - 4;
    R := Rect(x, FVol.Bottom + 1, x + cv.TextWidth(s) + 8, h);
    cv.Brush.Style := bsSolid; cv.Brush.Color := RGB(70, 76, 86); cv.FillRect(R);
    cv.Brush.Style := bsClear; cv.Font.Color := clWhite;
    cv.TextOut(R.Left + 4, R.Top + 3, s);
  end;

  { untung / rugi MT5 di kanan bawah area harga, 4x ukuran label atas }
  if PLText <> '' then
  begin
    cv.Brush.Style := bsClear;
    cv.Font.Size := 44; cv.Font.Style := [fsBold]; cv.Font.Color := PLColor;
    x := FPlot.Right - cv.TextWidth(PLText) - 12;
    y := FPlot.Bottom - cv.TextHeight(PLText) - 4;
    cv.TextOut(x, y, PLText);
    cv.Font.Size := 9; cv.Font.Color := clrMuted;
    cv.TextOut(FPlot.Right - cv.TextWidth(PLCap) - 14, y - 6, PLCap);
    cv.Font.Size := 8; cv.Font.Style := [];
  end;

  { modal di kiri bawah area harga, ukuran sama dengan untung / rugi }
  if ModalText <> '' then
  begin
    cv.Brush.Style := bsClear;
    cv.Font.Size := 44; cv.Font.Style := [fsBold]; cv.Font.Color := TitleColor;   { kuning (lebih tua di latar putih) }
    y := FPlot.Bottom - cv.TextHeight(ModalText) - 4;
    cv.TextOut(FPlot.Left + 12, y, ModalText);
    cv.Font.Size := 9; cv.Font.Color := clrMuted;
    cv.TextOut(FPlot.Left + 14, y - 6, 'MODAL');
    cv.Font.Size := 8; cv.Font.Style := [];
  end;

  { nama MA ditulis pada ujung kanan garisnya (digeser bila bertumpuk) }
  nTag := 0;
  cv.Font.Size := 7; cv.Font.Style := [fsBold];
  for m := 0 to 5 do
    if ShowMA[m] and (Length(MA[m]) = n) then
    begin
      i := i1;
      while (i >= i0) and (MA[m][i] <= 0) do Dec(i);
      if i < i0 then Continue;
      s := 'MA' + IntToStr(MAPer[m]);
      x := Min(XOf(i) + 4, FPlot.Right - cv.TextWidth(s) - 6);
      y := YOf(MA[m][i]) - 6;
      repeat
        moved := False;
        for j := 0 to nTag - 1 do
          if Abs(tagY[j] - y) < 13 then begin y := tagY[j] + 13; moved := True; end;
      until not moved;
      if (y < FPlot.Top) or (y > FPlot.Bottom - 12) then Continue;
      tagY[nTag] := y; Inc(nTag);
      R := Rect(x, y, x + cv.TextWidth(s) + 6, y + 13);
      cv.Brush.Style := bsSolid; cv.Brush.Color := MAColors[m]; cv.FillRect(R);
      cv.Brush.Style := bsClear; cv.Font.Color := clrBg;
      cv.TextOut(R.Left + 3, R.Top, s);
    end;
  cv.Font.Size := 8; cv.Font.Style := [];

  { info OHLC + legenda }
  cv.Brush.Style := bsClear;
  x := 6;
  cv.Font.Style := [fsBold]; cv.Font.Color := TitleColor;
  cv.TextOut(x, 4, Title); Inc(x, cv.TextWidth(Title) + 10);
  cv.Font.Style := [];
  if C[k].C >= C[k].O then col := clrGreen else col := clrRed;
  if C[k].O > 0 then p := (C[k].C - C[k].O) / C[k].O * 100 else p := 0;
  s := Format('O %s  H %s  L %s  C %s  (%s%%)  Amp %s%%',
    [FmtP(C[k].O, Digits), FmtP(C[k].H, Digits), FmtP(C[k].L, Digits), FmtP(C[k].C, Digits),
     FormatFloat('+0.00;-0.00', p), FormatFloat('0.00', (C[k].H - C[k].L) / Max(C[k].L, 1E-12) * 100)]);
  cv.Font.Color := col;
  cv.TextOut(x, 4, s);
  x := 6;
  for i := 0 to 5 do
    if ShowMA[i] and (Length(MA[i]) = n) then
    begin
      cv.Font.Color := MAColors[i];
      if MA[i][k] > 0 then s := Format('MA(%d): %s', [MAPer[i], FmtP(MA[i][k], Digits)])
      else s := Format('MA(%d): -', [MAPer[i]]);
      cv.TextOut(x, 19, s);
      Inc(x, cv.TextWidth(s) + 12);
    end;
  if ShowBB and (Length(BBU) = n) and (BBU[k] > 0) then
  begin
    cv.Font.Color := RGB(149, 117, 205);
    cv.TextOut(6, 33, Format('BOLL(20,2)  UP: %s  MB: %s  DN: %s',
      [FmtP(BBU[k], Digits), FmtP(BBM[k], Digits), FmtP(BBL[k], Digits)]));
  end;
  if not FAuto then
  begin
    cv.Font.Color := TitleColor;
    s := 'Skala manual (klik ganda = otomatis)';
    cv.TextOut(FPlot.Right - cv.TextWidth(s) - 8, 4, s);
  end;

  Canvas.Draw(0, 0, FBmp);
end;

procedure TChartView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then Exit;
  FDX := X; FDY := Y;
  FDScroll := FScroll; FDBarW := FBarW;
  if FAuto then begin FPMin := FLo; FPMax := FHi; end;
  FDPMin := FPMin; FDPMax := FPMax;
  if X > FPlot.Right then
  begin
    FDrag := 2;
    FAuto := False;
    FDPMin := FLo; FDPMax := FHi;
  end
  else if Y > FVol.Bottom then FDrag := 3
  else FDrag := 1;
end;

procedure TChartView.MouseMove(Shift: TShiftState; X, Y: Integer);
var f, c0, hh, dp: Double;
begin
  inherited;
  FMX := X; FMY := Y; FMouseIn := True;
  if X > FPlot.Right then Cursor := crSizeNS
  else if Y > FVol.Bottom then Cursor := crSizeWE
  else Cursor := crCross;
  case FDrag of
    1: begin
         FScroll := FDScroll + (X - FDX) / FBarW;
         ClampScroll;
         if not FAuto then
         begin
           dp := (Y - FDY) / Max(1, FPlot.Bottom - FPlot.Top) * (FDPMax - FDPMin);
           FPMin := FDPMin + dp; FPMax := FDPMax + dp;
         end;
       end;
    2: begin
         f := Exp((Y - FDY) / 160);
         c0 := (FDPMin + FDPMax) / 2; hh := (FDPMax - FDPMin) / 2 * f;
         FPMin := c0 - hh; FPMax := c0 + hh;
       end;
    3: begin
         FBarW := FDBarW * Exp((X - FDX) / 160);
         if FBarW < 1.5 then FBarW := 1.5;
         if FBarW > 60 then FBarW := 60;
         ClampScroll;
       end;
  end;
  Invalidate;
end;

procedure TChartView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  FDrag := 0;
end;

procedure TChartView.DblClick;
begin
  inherited;
  FAuto := True;
  Invalidate;
end;

procedure TChartView.Wheel(Delta: Integer; Shift: TShiftState);
var f, c0, hh: Double;
begin
  if ssCtrl in Shift then
  begin
    if FAuto then begin FPMin := FLo; FPMax := FHi; FAuto := False; end;
    if Delta > 0 then f := 0.9 else f := 1.1;
    c0 := (FPMin + FPMax) / 2; hh := (FPMax - FPMin) / 2 * f;
    FPMin := c0 - hh; FPMax := c0 + hh;
  end
  else if ssShift in Shift then
  begin
    if Delta > 0 then FScroll := FScroll + VisBars * 0.1 else FScroll := FScroll - VisBars * 0.1;
    ClampScroll;
  end
  else
  begin
    if Delta > 0 then FBarW := FBarW * 1.15 else FBarW := FBarW / 1.15;
    if FBarW < 1.5 then FBarW := 1.5;
    if FBarW > 60 then FBarW := 60;
    ClampScroll;
  end;
  Invalidate;
end;

procedure TChartView.ZoomIn;
begin
  Wheel(120, []);
end;

procedure TChartView.ZoomOut;
begin
  Wheel(-120, []);
end;

procedure TChartView.ResetView;
begin
  FBarW := 7; FScroll := -6; FAuto := True;
  Invalidate;
end;

initialization
  MAColors[0] := RGB(240, 185, 11);   { MA9   kuning }
  MAColors[1] := RGB(224, 64, 251);   { MA25  ungu magenta }
  MAColors[2] := RGB(0, 188, 212);    { MA99  cyan }
  MAColors[3] := RGB(255, 145, 0);    { MA200 oranye }
  MAColors[4] := RGB(41, 121, 255);   { MA500 biru }
  MAColors[5] := RGB(198, 255, 0);    { MA700 hijau lime }
end.
