unit uData;

{ Parsing data Binance, indikator teknikal, SMC (BOS / CHoCH / FVG),
  pola candle, pola grafik, persilangan MA, analisa multi timeframe dan sinyal }

interface

uses Windows, SysUtils, Classes, Math, StrUtils;

type
  TCandle = record
    T: Int64;
    O, H, L, C, V: Double;
  end;
  TCandles = array of TCandle;
  TDArr = array of Double;

  TStructEvt = record
    Kind: Integer;          { 1 = BOS, 2 = CHoCH }
    Dir: Integer;           { 1 bullish, -1 bearish }
    FromIdx, ToIdx: Integer;
    Level: Double;
  end;
  TStructEvts = array of TStructEvt;

  TStructInfo = record
    Trend: Integer;
    TrendStart: Integer;
    SH, SL: Double;
    SHi, SLi: Integer;
  end;

  TFVG = record
    Dir: Integer;
    StartIdx, EndIdx: Integer;  { EndIdx = -1 bila belum tertutup }
    Top, Bot: Double;
  end;
  TFVGs = array of TFVG;

  TPatMark = record
    Idx, Dir: Integer;
    Name, Short, Meaning: string;
  end;
  TPatMarks = array of TPatMark;

  TPivots = record
    Valid: Boolean;
    P, R1, R2, R3, S1, S2, S3: Double;
  end;

  TTicker = record
    Sym, Base: string;
    Last, Chg, High, Low, QVol, Pos: Double;
    Status: Integer;        { 1 breakout, -1 breakdown, 0 normal }
    IsGold: Boolean;
  end;
  TTickers = array of TTicker;

  TCross = record
    Fast, Slow: Integer;
    Idx, Dir: Integer;
    Soon: Boolean;
    SoonDir, SoonBars: Integer;
  end;
  TCrosses = array of TCross;

  TChartPat = record
    Name, Desc: string;
    Dir: Integer;
  end;
  TChartPats = array of TChartPat;

  TTFInfo = record
    OK: Boolean;
    Trend, TrendBars: Integer;
    ER, ATRp, AvgRangeP, Range20P, Chg20P, RSI, Last: Double;
    Sideways: Boolean;
  end;

  TSignal = record
    Score, Action: Integer;   { Action: 2 buy kuat, 1 buy lemah, 0 tunggu, -1, -2 }
    Entry, SL, TP1, TP2: Double;
    Reasons: string;
  end;

const
  MAPer: array[0..5] of Integer = (9, 25, 99, 200, 500, 700);

function PF(const S: string): Double;
function FmtP(V: Double; D: Integer): string;
function DigitsFor(P: Double): Integer;
function DurStr(Sec: Double): string;

function ParseKlines(const S: string; var A: TCandles): Boolean;
function ParseTickers(const S: string; var A: TTickers): Integer;
function JStr(const S: string; P1, P2: Integer; const Key: string): string;

function SMA(const A: TCandles; Per: Integer): TDArr;
procedure Bollinger(const A: TCandles; Per: Integer; K: Double; var Up, Mid, Lo: TDArr);
function RSIArr(const A: TCandles; Per: Integer): TDArr;
procedure MACDArr(const A: TCandles; var Macd, Sig, Hist: TDArr);
function ATRArr(const A: TCandles; Per: Integer): TDArr;

procedure ComputeStructure(const A: TCandles; L: Integer; var E: TStructEvts; var Info: TStructInfo);
procedure ComputeFVG(const A: TCandles; const ATR: TDArr; var F: TFVGs);
function DetectCandle(const A: TCandles; i: Integer; var M: TPatMark): Boolean;
procedure ComputeMarks(const A: TCandles; FromIdx: Integer; var M: TPatMarks);
function ComputePivots(const A: TCandles; TFSec: Integer): TPivots;
procedure ComputeCrosses(const A: TCandles; const MA: array of TDArr; var X: TCrosses);
procedure ChartPatterns(const A: TCandles; ATR: Double; var R: TChartPats);
function AnalyzeTF(const A: TCandles; Pip: Double): TTFInfo;
function ComputeSignal(const A: TCandles; const MA: array of TDArr; const BBU, BBL, RSI, Hist, ATR: TDArr;
  const SI: TStructInfo; HTF1, HTF4: Integer): TSignal;

implementation

function PF(const S: string): Double;
var code: Integer;
begin
  Val(Trim(S), Result, code);
  if code <> 0 then Result := 0;
end;

function FmtP(V: Double; D: Integer): string;
begin
  Result := FloatToStrF(V, ffFixed, 18, D);
end;

function DigitsFor(P: Double): Integer;
begin
  if P >= 100 then Result := 2
  else if P >= 1 then Result := 4
  else if P >= 0.01 then Result := 5
  else Result := 8;
end;

function DurStr(Sec: Double): string;
var m: Int64;
begin
  m := Round(Sec / 60);
  if m < 60 then Result := IntToStr(m) + ' menit'
  else if m < 60 * 48 then Result := Format('%d jam %d mnt', [m div 60, m mod 60])
  else Result := Format('%d hari %d jam', [m div 1440, (m mod 1440) div 60]);
end;

{ ---------------- Parsing JSON sederhana ---------------- }

function ParseKlines(const S: string; var A: TCandles): Boolean;
var p, len, f, st, cnt: Integer; fields: array[0..5] of string;
begin
  Result := False;
  len := Length(S); p := 1; cnt := 0;
  while (p <= len) and (S[p] <> '[') do Inc(p);
  if p > len then Exit;
  Inc(p);
  SetLength(A, 1600);
  while p <= len do
  begin
    while (p <= len) and not (S[p] in ['[', ']']) do Inc(p);
    if (p > len) or (S[p] = ']') then Break;
    Inc(p);
    f := 0;
    while (p <= len) and (S[p] <> ']') do
    begin
      while (p <= len) and (S[p] in [' ', ',', '"', #9, #10, #13]) do Inc(p);
      st := p;
      while (p <= len) and not (S[p] in [',', '"', ']']) do Inc(p);
      if f <= 5 then fields[f] := Copy(S, st, p - st);
      Inc(f);
      if (p <= len) and (S[p] = '"') then Inc(p);
    end;
    Inc(p);
    if f >= 6 then
    begin
      if cnt >= Length(A) then SetLength(A, cnt * 2);
      A[cnt].T := StrToInt64Def(fields[0], 0);
      A[cnt].O := PF(fields[1]);
      A[cnt].H := PF(fields[2]);
      A[cnt].L := PF(fields[3]);
      A[cnt].C := PF(fields[4]);
      A[cnt].V := PF(fields[5]);
      Inc(cnt);
    end;
  end;
  SetLength(A, cnt);
  Result := cnt > 0;
end;

function JStr(const S: string; P1, P2: Integer; const Key: string): string;
var k, p, st: Integer;
begin
  Result := '';
  k := PosEx('"' + Key + '":', S, P1);
  if (k = 0) or (k > P2) then Exit;
  p := k + Length(Key) + 3;
  while (p <= P2) and (S[p] = ' ') do Inc(p);
  if p > P2 then Exit;
  if S[p] = '"' then
  begin
    Inc(p); st := p;
    while (p <= P2) and (S[p] <> '"') do
    begin
      if S[p] = '\' then Inc(p);
      Inc(p);
    end;
    Result := StringReplace(Copy(S, st, p - st), '\/', '/', [rfReplaceAll]);
  end
  else
  begin
    st := p;
    while (p <= P2) and not (S[p] in [',', '}']) do Inc(p);
    Result := Trim(Copy(S, st, p - st));
  end;
end;

function ParseTickers(const S: string; var A: TTickers): Integer;
var p, q, cnt: Integer;
begin
  cnt := 0;
  SetLength(A, 4000);
  p := 1;
  while True do
  begin
    p := PosEx('{', S, p);
    if p = 0 then Break;
    q := PosEx('}', S, p);
    if q = 0 then Break;
    if cnt >= Length(A) then SetLength(A, cnt * 2);
    with A[cnt] do
    begin
      Sym := JStr(S, p, q, 'symbol');
      Last := PF(JStr(S, p, q, 'lastPrice'));
      Chg := PF(JStr(S, p, q, 'priceChangePercent'));
      High := PF(JStr(S, p, q, 'highPrice'));
      Low := PF(JStr(S, p, q, 'lowPrice'));
      QVol := PF(JStr(S, p, q, 'quoteVolume'));
      Base := Sym;
      Status := 0; Pos := 0.5; IsGold := False;
      if High > Low then Pos := (Last - Low) / (High - Low);
    end;
    if A[cnt].Sym <> '' then Inc(cnt);
    p := q + 1;
  end;
  SetLength(A, cnt);
  Result := cnt;
end;

{ ---------------- Indikator ---------------- }

function SMA(const A: TCandles; Per: Integer): TDArr;
var i: Integer; s: Double;
begin
  SetLength(Result, Length(A));
  s := 0;
  for i := 0 to High(A) do
  begin
    s := s + A[i].C;
    if i >= Per then s := s - A[i - Per].C;
    if i >= Per - 1 then Result[i] := s / Per else Result[i] := 0;
  end;
end;

procedure Bollinger(const A: TCandles; Per: Integer; K: Double; var Up, Mid, Lo: TDArr);
var i, j, n: Integer; m, v: Double;
begin
  n := Length(A);
  Mid := SMA(A, Per);
  SetLength(Up, n); SetLength(Lo, n);
  for i := 0 to n - 1 do
  begin
    if i < Per - 1 then begin Up[i] := 0; Lo[i] := 0; Continue; end;
    m := Mid[i]; v := 0;
    for j := i - Per + 1 to i do v := v + Sqr(A[j].C - m);
    v := Sqrt(v / Per);
    Up[i] := m + K * v;
    Lo[i] := m - K * v;
  end;
end;

function RSIArr(const A: TCandles; Per: Integer): TDArr;
var i, n: Integer; g, l, d, ag, al: Double;
begin
  n := Length(A);
  SetLength(Result, n);
  for i := 0 to n - 1 do Result[i] := 50;
  if n <= Per + 1 then Exit;
  ag := 0; al := 0;
  for i := 1 to Per do
  begin
    d := A[i].C - A[i - 1].C;
    if d > 0 then ag := ag + d else al := al - d;
  end;
  ag := ag / Per; al := al / Per;
  for i := Per + 1 to n - 1 do
  begin
    d := A[i].C - A[i - 1].C;
    if d > 0 then begin g := d; l := 0; end else begin g := 0; l := -d; end;
    ag := (ag * (Per - 1) + g) / Per;
    al := (al * (Per - 1) + l) / Per;
    if al = 0 then Result[i] := 100 else Result[i] := 100 - 100 / (1 + ag / al);
  end;
end;

procedure MACDArr(const A: TCandles; var Macd, Sig, Hist: TDArr);
var i, n: Integer; e12, e26, k12, k26, k9: Double;
begin
  n := Length(A);
  SetLength(Macd, n); SetLength(Sig, n); SetLength(Hist, n);
  if n = 0 then Exit;
  k12 := 2 / 13; k26 := 2 / 27; k9 := 2 / 10;
  e12 := A[0].C; e26 := A[0].C;
  for i := 0 to n - 1 do
  begin
    e12 := A[i].C * k12 + e12 * (1 - k12);
    e26 := A[i].C * k26 + e26 * (1 - k26);
    Macd[i] := e12 - e26;
    if i = 0 then Sig[i] := Macd[i] else Sig[i] := Macd[i] * k9 + Sig[i - 1] * (1 - k9);
    Hist[i] := Macd[i] - Sig[i];
  end;
end;

function ATRArr(const A: TCandles; Per: Integer): TDArr;
var i, n: Integer; tr, av: Double;
begin
  n := Length(A);
  SetLength(Result, n);
  av := 0;
  for i := 0 to n - 1 do
  begin
    if i = 0 then tr := A[i].H - A[i].L
    else tr := Max(A[i].H - A[i].L, Max(Abs(A[i].H - A[i - 1].C), Abs(A[i].L - A[i - 1].C)));
    if i < Per then av := (av * i + tr) / (i + 1)
    else av := (av * (Per - 1) + tr) / Per;
    Result[i] := av;
  end;
end;

{ ---------------- Struktur pasar (SMC) ---------------- }

procedure ComputeStructure(const A: TCandles; L: Integer; var E: TStructEvts; var Info: TStructInfo);
var i, j, k, n, cnt: Integer; isH, isL, shB, slB: Boolean;

  procedure AddEvt(AKind, ADir, AFrom, ATo: Integer; ALevel: Double);
  begin
    if cnt >= Length(E) then SetLength(E, cnt * 2 + 16);
    E[cnt].Kind := AKind; E[cnt].Dir := ADir;
    E[cnt].FromIdx := AFrom; E[cnt].ToIdx := ATo; E[cnt].Level := ALevel;
    Inc(cnt);
  end;

begin
  n := Length(A); cnt := 0;
  SetLength(E, 0);
  FillChar(Info, SizeOf(Info), 0);
  Info.SHi := -1; Info.SLi := -1;
  shB := True; slB := True;
  for i := 0 to n - 1 do
  begin
    j := i - L;
    if j >= L then
    begin
      isH := True; isL := True;
      for k := j - L to j + L do
        if k <> j then
        begin
          if A[k].H > A[j].H then isH := False;
          if A[k].L < A[j].L then isL := False;
        end;
      if isH then begin Info.SH := A[j].H; Info.SHi := j; shB := False; end;
      if isL then begin Info.SL := A[j].L; Info.SLi := j; slB := False; end;
    end;
    if (Info.SHi >= 0) and (not shB) and (A[i].C > Info.SH) then
    begin
      if Info.Trend = -1 then AddEvt(2, 1, Info.SHi, i, Info.SH) else AddEvt(1, 1, Info.SHi, i, Info.SH);
      if Info.Trend <> 1 then Info.TrendStart := i;
      Info.Trend := 1; shB := True;
    end;
    if (Info.SLi >= 0) and (not slB) and (A[i].C < Info.SL) then
    begin
      if Info.Trend = 1 then AddEvt(2, -1, Info.SLi, i, Info.SL) else AddEvt(1, -1, Info.SLi, i, Info.SL);
      if Info.Trend <> -1 then Info.TrendStart := i;
      Info.Trend := -1; slB := True;
    end;
  end;
  SetLength(E, cnt);
end;

procedure ComputeFVG(const A: TCandles; const ATR: TDArr; var F: TFVGs);
var i, k, n, cnt: Integer; g: Double;
begin
  n := Length(A); cnt := 0;
  SetLength(F, 0);
  for i := 2 to n - 1 do
  begin
    g := 0.15 * ATR[i];
    if (A[i].L > A[i - 2].H) and (A[i].L - A[i - 2].H >= g) then
    begin
      SetLength(F, cnt + 1);
      F[cnt].Dir := 1; F[cnt].StartIdx := i - 1; F[cnt].EndIdx := -1;
      F[cnt].Top := A[i].L; F[cnt].Bot := A[i - 2].H;
      Inc(cnt);
    end
    else if (A[i].H < A[i - 2].L) and (A[i - 2].L - A[i].H >= g) then
    begin
      SetLength(F, cnt + 1);
      F[cnt].Dir := -1; F[cnt].StartIdx := i - 1; F[cnt].EndIdx := -1;
      F[cnt].Top := A[i - 2].L; F[cnt].Bot := A[i].H;
      Inc(cnt);
    end;
  end;
  for i := 0 to cnt - 1 do
    for k := F[i].StartIdx + 2 to n - 1 do
      if ((F[i].Dir = 1) and (A[k].L <= F[i].Bot)) or ((F[i].Dir = -1) and (A[k].H >= F[i].Top)) then
      begin
        F[i].EndIdx := k;
        Break;
      end;
end;

{ ---------------- Pola candle ---------------- }

function DetectCandle(const A: TCandles; i: Integer; var M: TPatMark): Boolean;
var o, h, l, c, body, rng, up, lo, avgB, avgR, b1, b2: Double; k, tr: Integer;

  procedure SetM(ADir: Integer; const AName, AShort, AMean: string);
  begin
    M.Idx := i; M.Dir := ADir; M.Name := AName; M.Short := AShort; M.Meaning := AMean;
  end;

begin
  Result := False;
  if (i < 6) or (i > High(A)) then Exit;
  avgB := 0; avgR := 0;
  for k := i - 10 to i - 1 do
    if k >= 0 then
    begin
      avgB := avgB + Abs(A[k].C - A[k].O);
      avgR := avgR + (A[k].H - A[k].L);
    end;
  avgB := avgB / 10; avgR := avgR / 10;
  if avgR <= 0 then Exit;
  o := A[i].O; h := A[i].H; l := A[i].L; c := A[i].C;
  body := Abs(c - o); rng := h - l;
  up := h - Max(o, c); lo := Min(o, c) - l;
  if A[i - 1].C < A[i - 6].C then tr := -1 else tr := 1;
  b2 := Abs(A[i - 2].C - A[i - 2].O);
  b1 := Abs(A[i - 1].C - A[i - 1].O);
  Result := True;
  { 3 candle }
  if (A[i - 2].C < A[i - 2].O) and (b2 > avgB) and (b1 < 0.4 * b2) and (c > o) and
     (c > (A[i - 2].O + A[i - 2].C) / 2) then
    SetM(1, 'Morning Star', 'MS', 'Pembalikan NAIK kuat: jual melemah, pembeli mengambil alih.')
  else if (A[i - 2].C > A[i - 2].O) and (b2 > avgB) and (b1 < 0.4 * b2) and (c < o) and
     (c < (A[i - 2].O + A[i - 2].C) / 2) then
    SetM(-1, 'Evening Star', 'ES', 'Pembalikan TURUN kuat: beli melemah, penjual mengambil alih.')
  else if (A[i - 2].C > A[i - 2].O) and (A[i - 1].C > A[i - 1].O) and (c > o) and
     (A[i - 1].C > A[i - 2].C) and (c > A[i - 1].C) and (b2 > 0.6 * avgB) and (b1 > 0.6 * avgB) and (body > 0.6 * avgB) then
    SetM(1, 'Three White Soldiers', '3WS', 'Tiga candle hijau beruntun: momentum naik kuat.')
  else if (A[i - 2].C < A[i - 2].O) and (A[i - 1].C < A[i - 1].O) and (c < o) and
     (A[i - 1].C < A[i - 2].C) and (c < A[i - 1].C) and (b2 > 0.6 * avgB) and (b1 > 0.6 * avgB) and (body > 0.6 * avgB) then
    SetM(-1, 'Three Black Crows', '3BC', 'Tiga candle merah beruntun: momentum turun kuat.')
  { 2 candle }
  else if (A[i - 1].C < A[i - 1].O) and (c > o) and (c >= A[i - 1].O) and (o <= A[i - 1].C) and (body > b1) then
    SetM(1, 'Bullish Engulfing', 'BuE', 'Candle hijau menelan candle merah: sinyal pembalikan NAIK.')
  else if (A[i - 1].C > A[i - 1].O) and (c < o) and (c <= A[i - 1].O) and (o >= A[i - 1].C) and (body > b1) then
    SetM(-1, 'Bearish Engulfing', 'BeE', 'Candle merah menelan candle hijau: sinyal pembalikan TURUN.')
  else if (A[i - 1].C < A[i - 1].O) and (b1 > avgB) and (c > o) and (o <= A[i - 1].C) and
     (c > (A[i - 1].O + A[i - 1].C) / 2) and (c < A[i - 1].O) then
    SetM(1, 'Piercing Line', 'PL', 'Pembeli menembus separuh candle merah: potensi naik.')
  else if (A[i - 1].C > A[i - 1].O) and (b1 > avgB) and (c < o) and (o >= A[i - 1].C) and
     (c < (A[i - 1].O + A[i - 1].C) / 2) and (c > A[i - 1].O) then
    SetM(-1, 'Dark Cloud Cover', 'DCC', 'Penjual menekan separuh candle hijau: potensi turun.')
  { 1 candle }
  else if (rng > 0.5 * avgR) and (lo >= 2 * body) and (up <= 0.25 * rng) and (tr = -1) then
    SetM(1, 'Hammer', 'H', 'Sumbu bawah panjang setelah turun: tekanan beli kuat, potensi naik.')
  else if (rng > 0.5 * avgR) and (lo >= 2 * body) and (up <= 0.25 * rng) and (tr = 1) then
    SetM(-1, 'Hanging Man', 'HM', 'Bentuk hammer di puncak: waspada pembalikan turun.')
  else if (rng > 0.5 * avgR) and (up >= 2 * body) and (lo <= 0.25 * rng) and (tr = 1) then
    SetM(-1, 'Shooting Star', 'SS', 'Sumbu atas panjang setelah naik: tekanan jual kuat, potensi turun.')
  else if (rng > 0.5 * avgR) and (up >= 2 * body) and (lo <= 0.25 * rng) and (tr = -1) then
    SetM(1, 'Inverted Hammer', 'IH', 'Sumbu atas panjang di dasar: pembeli mulai mencoba, tunggu konfirmasi.')
  else if (rng > 0.3 * avgR) and (body <= 0.08 * rng) then
  begin
    if lo > 0.6 * rng then SetM(1, 'Dragonfly Doji', 'DD', 'Doji sumbu bawah panjang: penolakan harga bawah.')
    else if up > 0.6 * rng then SetM(-1, 'Gravestone Doji', 'GD', 'Doji sumbu atas panjang: penolakan harga atas.')
    else SetM(0, 'Doji', 'D', 'Ragu-ragu: kekuatan beli dan jual seimbang, tunggu konfirmasi.');
  end
  else if (body >= 0.9 * rng) and (body > 1.5 * avgB) then
  begin
    if c > o then SetM(1, 'Bullish Marubozu', 'MB', 'Candle hijau penuh tanpa sumbu: pembeli dominan.')
    else SetM(-1, 'Bearish Marubozu', 'MB', 'Candle merah penuh tanpa sumbu: penjual dominan.');
  end
  else
    Result := False;
end;

procedure ComputeMarks(const A: TCandles; FromIdx: Integer; var M: TPatMarks);
var i, cnt: Integer; pm: TPatMark;
begin
  cnt := 0; SetLength(M, 0);
  if FromIdx < 6 then FromIdx := 6;
  for i := FromIdx to High(A) do
    if DetectCandle(A, i, pm) then
    begin
      SetLength(M, cnt + 1);
      M[cnt] := pm;
      Inc(cnt);
    end;
end;

{ ---------------- Pivot S1-S3 / R1-R3 ---------------- }

function PeriodKey(T: Int64; TFSec: Integer): Integer;
var y, m, d: Word;
begin
  if TFSec < 86400 then Result := T div 86400000
  else if TFSec < 604800 then Result := (T div 86400000 + 3) div 7
  else
  begin
    DecodeDate(T / 86400000 + 25569, y, m, d);
    Result := y * 12 + m;
  end;
end;

function ComputePivots(const A: TCandles; TFSec: Integer): TPivots;
var i, n, lastK, pk: Integer; h, l, c: Double; found: Boolean;
begin
  FillChar(Result, SizeOf(Result), 0);
  n := Length(A);
  if n < 10 then Exit;
  lastK := PeriodKey(A[n - 1].T, TFSec);
  pk := -1; found := False; h := 0; l := 0; c := 0;
  for i := n - 1 downto 0 do
  begin
    if PeriodKey(A[i].T, TFSec) < lastK then
    begin
      if pk = -1 then begin pk := PeriodKey(A[i].T, TFSec); h := A[i].H; l := A[i].L; c := A[i].C; found := True; end
      else if PeriodKey(A[i].T, TFSec) <> pk then Break
      else begin h := Max(h, A[i].H); l := Min(l, A[i].L); end;
    end;
  end;
  if not found then
  begin
    h := A[0].H; l := A[0].L; c := A[n - 2].C;
    for i := 0 to n - 2 do begin h := Max(h, A[i].H); l := Min(l, A[i].L); end;
  end;
  with Result do
  begin
    Valid := True;
    P := (h + l + c) / 3;
    R1 := 2 * P - l;  S1 := 2 * P - h;
    R2 := P + (h - l); S2 := P - (h - l);
    R3 := h + 2 * (P - l); S3 := l - 2 * (h - P);
  end;
end;

{ ---------------- Persilangan MA ---------------- }

procedure ComputeCrosses(const A: TCandles; const MA: array of TDArr; var X: TCrosses);
const PF_: array[0..6] of Integer = (0, 1, 0, 2, 1, 3, 4);
      PS_: array[0..6] of Integer = (1, 2, 2, 3, 3, 4, 5);
var p, i, n: Integer; f, s: TDArr; d0, d1, d, dp, rate: Double;
begin
  n := Length(A);
  SetLength(X, 7);
  for p := 0 to 6 do
  begin
    f := MA[PF_[p]]; s := MA[PS_[p]];
    X[p].Fast := MAPer[PF_[p]]; X[p].Slow := MAPer[PS_[p]];
    X[p].Idx := -1; X[p].Dir := 0; X[p].Soon := False;
    if n < 5 then Continue;
    for i := n - 1 downto 1 do
    begin
      if (f[i] = 0) or (s[i] = 0) or (f[i - 1] = 0) or (s[i - 1] = 0) then Break;
      d1 := f[i] - s[i]; d0 := f[i - 1] - s[i - 1];
      if (d1 > 0) <> (d0 > 0) then
      begin
        X[p].Idx := i;
        if d1 > 0 then X[p].Dir := 1 else X[p].Dir := -1;
        Break;
      end;
    end;
    if (f[n - 4] <> 0) and (s[n - 4] <> 0) and (s[n - 1] <> 0) then
    begin
      d := f[n - 1] - s[n - 1]; dp := f[n - 4] - s[n - 4];
      if (Abs(d) < Abs(dp)) and ((d > 0) = (dp > 0)) then
      begin
        rate := (Abs(dp) - Abs(d)) / 3;
        if (rate > 0) and (Abs(d) / rate <= 12) then
        begin
          X[p].Soon := True;
          X[p].SoonBars := Round(Abs(d) / rate) + 1;
          if d < 0 then X[p].SoonDir := 1 else X[p].SoonDir := -1;
        end;
      end;
    end;
  end;
end;

{ ---------------- Pola grafik ---------------- }

procedure ChartPatterns(const A: TCandles; ATR: Double; var R: TChartPats);
var n, i, j, nh, nl, cnt, st: Integer;
    hi, li: array of Integer;
    tol, neck, last, mv, cr, r1, r2, mx, mn: Double; isH, isL: Boolean;

  procedure Add(const AName, ADesc: string; ADir: Integer);
  begin
    SetLength(R, cnt + 1);
    R[cnt].Name := AName; R[cnt].Desc := ADesc; R[cnt].Dir := ADir;
    Inc(cnt);
  end;

  function MinL(i1, i2: Integer): Double;
  var k: Integer;
  begin
    Result := A[i1].L;
    for k := i1 to i2 do if A[k].L < Result then Result := A[k].L;
  end;

  function MaxH(i1, i2: Integer): Double;
  var k: Integer;
  begin
    Result := A[i1].H;
    for k := i1 to i2 do if A[k].H > Result then Result := A[k].H;
  end;

begin
  cnt := 0; SetLength(R, 0);
  n := Length(A);
  if n < 60 then Exit;
  last := A[n - 1].C;
  tol := Max(ATR * 0.6, last * 0.0015);
  nh := 0; nl := 0;
  st := n - 200; if st < 5 then st := 5;
  for i := st to n - 6 do
  begin
    isH := True; isL := True;
    for j := i - 5 to i + 5 do
      if j <> i then
      begin
        if A[j].H > A[i].H then isH := False;
        if A[j].L < A[i].L then isL := False;
      end;
    if isH then begin SetLength(hi, nh + 1); hi[nh] := i; Inc(nh); end;
    if isL then begin SetLength(li, nl + 1); li[nl] := i; Inc(nl); end;
  end;

  if (nh >= 2) and (Abs(A[hi[nh - 1]].H - A[hi[nh - 2]].H) <= tol) and (hi[nh - 1] - hi[nh - 2] >= 5) and (n - 1 - hi[nh - 1] <= 40) then
  begin
    neck := MinL(hi[nh - 2], hi[nh - 1]);
    if A[hi[nh - 1]].H - neck > 2 * tol then
    begin
      if last < neck then
        Add('Double Top', Format('TERKONFIRMASI: harga menembus neckline %s. Target %s. SL di atas puncak %s.',
          [FmtP(neck, DigitsFor(last)), FmtP(neck - (A[hi[nh - 1]].H - neck), DigitsFor(last)), FmtP(A[hi[nh - 1]].H, DigitsFor(last))]), -1)
      else
        Add('Double Top (terbentuk)', Format('Dua puncak sejajar di resistance. Tunggu breakdown neckline %s dengan volume tinggi untuk SELL.',
          [FmtP(neck, DigitsFor(last))]), -1);
    end;
  end;

  if (nl >= 2) and (Abs(A[li[nl - 1]].L - A[li[nl - 2]].L) <= tol) and (li[nl - 1] - li[nl - 2] >= 5) and (n - 1 - li[nl - 1] <= 40) then
  begin
    neck := MaxH(li[nl - 2], li[nl - 1]);
    if neck - A[li[nl - 1]].L > 2 * tol then
    begin
      if last > neck then
        Add('Double Bottom', Format('TERKONFIRMASI: harga menembus neckline %s. Target %s. SL di bawah dasar %s.',
          [FmtP(neck, DigitsFor(last)), FmtP(neck + (neck - A[li[nl - 1]].L), DigitsFor(last)), FmtP(A[li[nl - 1]].L, DigitsFor(last))]), 1)
      else
        Add('Double Bottom (terbentuk)', Format('Dua dasar sejajar di support. Tunggu breakout neckline %s dengan volume tinggi untuk BUY.',
          [FmtP(neck, DigitsFor(last))]), 1);
    end;
  end;

  if (nh >= 3) and (n - 1 - hi[nh - 1] <= 40) then
  begin
    r1 := A[hi[nh - 3]].H; mx := A[hi[nh - 2]].H; r2 := A[hi[nh - 1]].H;
    if (mx > r1 + tol * 0.5) and (mx > r2 + tol * 0.5) and (Abs(r1 - r2) <= tol * 1.5) then
    begin
      neck := (MinL(hi[nh - 3], hi[nh - 2]) + MinL(hi[nh - 2], hi[nh - 1])) / 2;
      Add('Head and Shoulders', Format('Pola pembalikan BEARISH. Neckline %s. Entry SELL setelah break neckline + volume tinggi, SL di atas bahu kanan.',
        [FmtP(neck, DigitsFor(last))]), -1);
    end;
  end;

  if (nl >= 3) and (n - 1 - li[nl - 1] <= 40) then
  begin
    r1 := A[li[nl - 3]].L; mn := A[li[nl - 2]].L; r2 := A[li[nl - 1]].L;
    if (mn < r1 - tol * 0.5) and (mn < r2 - tol * 0.5) and (Abs(r1 - r2) <= tol * 1.5) then
    begin
      neck := (MaxH(li[nl - 3], li[nl - 2]) + MaxH(li[nl - 2], li[nl - 1])) / 2;
      Add('Inverse Head and Shoulders', Format('Pola pembalikan BULLISH. Neckline %s. Entry BUY setelah break neckline + volume tinggi, SL di bawah bahu kanan.',
        [FmtP(neck, DigitsFor(last))]), 1);
    end;
  end;

  if (nh >= 2) and (nl >= 2) and (n - 1 - hi[nh - 1] <= 50) and (n - 1 - li[nl - 1] <= 50) then
  begin
    if (Abs(A[hi[nh - 1]].H - A[hi[nh - 2]].H) <= tol) and (A[li[nl - 1]].L > A[li[nl - 2]].L + tol * 0.5) then
      Add('Ascending Triangle', Format('Resistance datar %s + support naik. Fokus BUY saat breakout ke atas.',
        [FmtP(A[hi[nh - 1]].H, DigitsFor(last))]), 1)
    else if (Abs(A[li[nl - 1]].L - A[li[nl - 2]].L) <= tol) and (A[hi[nh - 1]].H < A[hi[nh - 2]].H - tol * 0.5) then
      Add('Descending Triangle', Format('Support datar %s + resistance turun. Fokus SELL saat breakdown ke bawah.',
        [FmtP(A[li[nl - 1]].L, DigitsFor(last))]), -1)
    else if (A[hi[nh - 1]].H < A[hi[nh - 2]].H - tol * 0.5) and (A[li[nl - 1]].L > A[li[nl - 2]].L + tol * 0.5) then
      Add('Symmetrical Triangle', 'Harga menyempit (high turun, low naik). Entry searah breakout, biasanya searah tren utama.', 0);
  end;

  if n > 30 then
  begin
    mv := A[n - 11].C - A[n - 26].C;
    mx := MaxH(n - 10, n - 1); mn := MinL(n - 10, n - 1);
    cr := mx - mn;
    if (Abs(mv) > 4 * ATR) and (cr < 0.5 * Abs(mv)) then
    begin
      r1 := MaxH(n - 10, n - 6) - MinL(n - 10, n - 6);
      r2 := MaxH(n - 5, n - 1) - MinL(n - 5, n - 1);
      if r2 < 0.6 * r1 then
      begin
        if mv > 0 then Add('Bullish Pennant', 'Konsolidasi segitiga kecil setelah naik tajam. Tunggu breakout atas, SL di bawah pennant.', 1)
        else Add('Bearish Pennant', 'Konsolidasi segitiga kecil setelah turun tajam. Tunggu breakdown, SL di atas pennant.', -1);
      end
      else
      begin
        if mv > 0 then Add('Bullish Flag', Format('Konsolidasi kecil dalam tren naik. BUY saat breakout %s, SL di bawah flag %s.',
          [FmtP(mx, DigitsFor(last)), FmtP(mn, DigitsFor(last))]), 1)
        else Add('Bearish Flag', Format('Konsolidasi kecil dalam tren turun. SELL saat breakdown %s, SL di atas flag %s.',
          [FmtP(mn, DigitsFor(last)), FmtP(mx, DigitsFor(last))]), -1);
      end;
    end;
  end;
end;

{ ---------------- Analisa per timeframe ---------------- }

function AnalyzeTF(const A: TCandles; Pip: Double): TTFInfo;
var n, i, maT: Integer; atr, rsi, ma25, ma99: TDArr; s, hi, lo, path: Double;
    ev: TStructEvts; si: TStructInfo;
begin
  FillChar(Result, SizeOf(Result), 0);
  n := Length(A);
  if (n < 60) or (Pip <= 0) then Exit;
  Result.OK := True;
  atr := ATRArr(A, 14);
  rsi := RSIArr(A, 14);
  ma25 := SMA(A, 25);
  if n >= 99 then ma99 := SMA(A, 99) else ma99 := SMA(A, 50);
  Result.Last := A[n - 1].C;
  Result.ATRp := atr[n - 1] / Pip;
  Result.RSI := rsi[n - 1];
  s := 0; hi := A[n - 20].H; lo := A[n - 20].L; path := 0;
  for i := n - 20 to n - 1 do
  begin
    s := s + (A[i].H - A[i].L);
    hi := Max(hi, A[i].H); lo := Min(lo, A[i].L);
    path := path + Abs(A[i].C - A[i - 1].C);
  end;
  Result.AvgRangeP := s / 20 / Pip;
  Result.Range20P := (hi - lo) / Pip;
  Result.Chg20P := (A[n - 1].C - A[n - 21].C) / Pip;
  if path > 0 then Result.ER := Abs(A[n - 1].C - A[n - 21].C) / path;
  maT := 0;
  if (A[n - 1].C > ma25[n - 1]) and (ma25[n - 1] > ma99[n - 1]) then maT := 1
  else if (A[n - 1].C < ma25[n - 1]) and (ma25[n - 1] < ma99[n - 1]) then maT := -1;
  ComputeStructure(A, 3, ev, si);
  if (maT = 0) or (maT = si.Trend) then Result.Trend := si.Trend else Result.Trend := 0;
  if maT = si.Trend then Result.Trend := maT;
  Result.TrendBars := n - 1 - si.TrendStart;
  Result.Sideways := (Result.ER < 0.3) or (Result.Trend = 0);
end;

{ ---------------- Sinyal BUY / SELL ---------------- }

function ComputeSignal(const A: TCandles; const MA: array of TDArr; const BBU, BBL, RSI, Hist, ATR: TDArr;
  const SI: TStructInfo; HTF1, HTF4: Integer): TSignal;
var n, i, sc, k: Integer; c, m9, m25, m99, atrv, vAvg, risk: Double; pm: TPatMark; rs: string;

  procedure R(Pts: Integer; const Txt: string);
  begin
    sc := sc + Pts;
    if Pts > 0 then rs := rs + '+' + IntToStr(Pts) + '  ' + Txt + #13#10
    else if Pts < 0 then rs := rs + IntToStr(Pts) + '  ' + Txt + #13#10
    else rs := rs + ' 0  ' + Txt + #13#10;
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  n := Length(A);
  if n < 30 then Exit;
  sc := 0; rs := '';
  i := n - 1;
  c := A[i].C; m9 := MA[0][i]; m25 := MA[1][i]; m99 := MA[2][i];
  atrv := ATR[i];
  if (m25 > 0) and (m99 > 0) then
  begin
    if (c > m25) and (m25 > m99) then R(2, 'Harga > MA25 > MA99 (tren naik)')
    else if (c < m25) and (m25 < m99) then R(-2, 'Harga < MA25 < MA99 (tren turun)')
    else if c > m99 then R(1, 'Harga di atas MA99')
    else R(-1, 'Harga di bawah MA99');
  end;
  if (m9 > 0) and (m25 > 0) then
    if m9 > m25 then R(1, 'MA9 di atas MA25 (momentum naik)') else R(-1, 'MA9 di bawah MA25 (momentum turun)');
  if SI.Trend = 1 then R(2, 'Struktur SMC bullish (BOS/CHoCH ke atas)')
  else if SI.Trend = -1 then R(-2, 'Struktur SMC bearish (BOS/CHoCH ke bawah)');
  if Hist[i] > 0 then
  begin
    if Hist[i] > Hist[i - 1] then R(1, 'MACD histogram positif & menguat') else R(0, 'MACD positif tapi melemah');
  end
  else
  begin
    if Hist[i] < Hist[i - 1] then R(-1, 'MACD histogram negatif & melemah') else R(0, 'MACD negatif tapi membaik');
  end;
  if RSI[i] < 30 then R(1, Format('RSI %.1f oversold (potensi pantul naik)', [RSI[i]]))
  else if RSI[i] > 70 then R(-1, Format('RSI %.1f overbought (potensi koreksi turun)', [RSI[i]]))
  else if RSI[i] > 55 then R(1, Format('RSI %.1f di atas 55 (bullish)', [RSI[i]]))
  else if RSI[i] < 45 then R(-1, Format('RSI %.1f di bawah 45 (bearish)', [RSI[i]]));
  if (BBL[i] > 0) and (A[i - 1].L <= BBL[i - 1]) and (c > A[i].O) then R(1, 'Pantulan dari Bollinger Band bawah')
  else if (BBU[i] > 0) and (A[i - 1].H >= BBU[i - 1]) and (c < A[i].O) then R(-1, 'Penolakan dari Bollinger Band atas');
  if DetectCandle(A, i - 1, pm) and (pm.Dir <> 0) then
  begin
    if pm.Name[1] in ['M', 'T', 'B'] then k := 2 else k := 1;
    R(k * pm.Dir, 'Pola candle: ' + pm.Name);
  end;
  vAvg := 0;
  for k := i - 21 to i - 2 do vAvg := vAvg + A[k].V;
  vAvg := vAvg / 20;
  if (vAvg > 0) and (A[i - 1].V > 1.5 * vAvg) then
  begin
    if A[i - 1].C > A[i - 1].O then R(1, 'Volume besar pada candle hijau (konfirmasi beli)')
    else R(-1, 'Volume besar pada candle merah (konfirmasi jual)');
  end;
  if HTF1 <> 0 then R(HTF1, 'Tren timeframe 1 jam');
  if HTF4 <> 0 then R(HTF4, 'Tren timeframe 4 jam');

  Result.Score := sc;
  Result.Reasons := rs;
  if sc >= 6 then Result.Action := 2
  else if sc >= 3 then Result.Action := 1
  else if sc <= -6 then Result.Action := -2
  else if sc <= -3 then Result.Action := -1
  else Result.Action := 0;

  Result.Entry := c;
  if sc >= 0 then
  begin
    if (SI.SLi >= 0) and (SI.SL < c) and (c - SI.SL <= 3 * atrv) and (c - SI.SL >= 0.5 * atrv) then
      Result.SL := SI.SL - 0.2 * atrv
    else Result.SL := c - 1.5 * atrv;
    risk := c - Result.SL;
    Result.TP1 := c + 2 * risk;
    Result.TP2 := c + 3 * risk;
  end
  else
  begin
    if (SI.SHi >= 0) and (SI.SH > c) and (SI.SH - c <= 3 * atrv) and (SI.SH - c >= 0.5 * atrv) then
      Result.SL := SI.SH + 0.2 * atrv
    else Result.SL := c + 1.5 * atrv;
    risk := Result.SL - c;
    Result.TP1 := c - 2 * risk;
    Result.TP2 := c - 3 * risk;
  end;
end;

end.
