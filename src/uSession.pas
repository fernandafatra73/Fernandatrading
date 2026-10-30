unit uSession;

{ Sesi trading (Sydney, Tokyo, London, New York) dengan aturan DST,
  serta kalender berita ekonomi (FOMC, NFP, CPI, dll) }

interface

uses Windows, SysUtils, Classes, DateUtils, Math, StrUtils;

type
  TSessState = record
    IsOpen: Boolean;
    OpenU, CloseU: TDateTime;   { sesi aktif atau sesi berikutnya (UTC) }
    NextChange: TDateTime;
  end;

  TEcoEvent = record
    TimeU: TDateTime;
    Title, Country, Impact, Forecast, Previous: string;
    Alert5, Alert0, Builtin: Boolean;
  end;
  TEcoEvents = array of TEcoEvent;

const
  SessName: array[0..3] of string = ('Sydney', 'Tokyo', 'London', 'New York');
  SessOpenH: array[0..3] of Double = (7, 9, 8, 8);
  SessCloseH: array[0..3] of Double = (16, 18, 17, 17);

function NowUTC: TDateTime;
function LocalOffsetH: Double;
function ToLocal(U: TDateTime): TDateTime;
function ZoneName: string;
function ZoneOffsetH(Idx: Integer; U: TDateTime): Double;
function NYOffsetH(U: TDateTime): Double;
procedure SessionWindow(Idx: Integer; D: TDateTime; out OpenU, CloseU: TDateTime);
function GetSessState(Idx: Integer; NowU: TDateTime): TSessState;
function CountdownStr(Sec: Double): string;

type
  TWIBPhase = record
    Idx: Integer;                 { 0..7, -1 = akhir pekan }
    Name, Sessions, Cross, Signal: string;
    StartH, EndH: Integer;        { jam WIB }
  end;

function NowWIB: TDateTime;
function GetWIBPhase(W: TDateTime): TWIBPhase;
function NextWIBPhaseAt(W: TDateTime): TDateTime;

procedure BuildBuiltinEvents(var E: TEcoEvents);
function ParseFFCalendar(const S: string; var E: TEcoEvents): Integer;
procedure LoadUserEvents(const FileName: string; var E: TEcoEvents);
procedure SortEvents(var E: TEcoEvents);
function IsAlarmEvent(const Ev: TEcoEvent): Boolean;
function EventImpactText(const Title: string): string;

implementation

uses uData;

var
  FLocalOff: Double = -999;

function NowUTC: TDateTime;
var st: TSystemTime;
begin
  GetSystemTime(st);
  Result := SystemTimeToDateTime(st);
end;

function LocalOffsetH: Double;
begin
  if FLocalOff = -999 then
    FLocalOff := Round((Now - NowUTC) * 24 * 4) / 4;
  Result := FLocalOff;
end;

function ToLocal(U: TDateTime): TDateTime;
begin
  Result := U + LocalOffsetH / 24;
end;

function ZoneName: string;
var o: Double;
begin
  o := LocalOffsetH;
  if o = 7 then Result := 'WIB'
  else if o = 8 then Result := 'WITA'
  else if o = 9 then Result := 'WIT'
  else if o >= 0 then Result := 'UTC+' + FloatToStr(o)
  else Result := 'UTC' + FloatToStr(o);
end;

function NthSunday(Y, M, N: Integer): TDateTime;
var d: TDateTime;
begin
  d := EncodeDate(Y, M, 1);
  while DayOfTheWeek(d) <> 7 do d := d + 1;
  Result := d + 7 * (N - 1);
end;

function LastSunday(Y, M: Integer): TDateTime;
var d: TDateTime;
begin
  d := EndOfAMonth(Y, M);
  d := Trunc(d);
  while DayOfTheWeek(d) <> 7 do d := d - 1;
  Result := d;
end;

function NYOffsetH(U: TDateTime): Double;
var y: Integer; s, e: TDateTime;
begin
  y := YearOf(U);
  s := NthSunday(y, 3, 2) + 7 / 24;
  e := NthSunday(y, 11, 1) + 6 / 24;
  if (U >= s) and (U < e) then Result := -4 else Result := -5;
end;

function ZoneOffsetH(Idx: Integer; U: TDateTime): Double;
var y: Integer; s, e: TDateTime;
begin
  y := YearOf(U);
  case Idx of
    0: begin
         s := NthSunday(y, 4, 1) - 8 / 24;
         e := NthSunday(y, 10, 1) - 8 / 24;
         if (U >= s) and (U < e) then Result := 10 else Result := 11;
       end;
    1: Result := 9;
    2: begin
         s := LastSunday(y, 3) + 1 / 24;
         e := LastSunday(y, 10) + 1 / 24;
         if (U >= s) and (U < e) then Result := 1 else Result := 0;
       end;
  else
    Result := NYOffsetH(U);
  end;
end;

procedure SessionWindow(Idx: Integer; D: TDateTime; out OpenU, CloseU: TDateTime);
var lo, lc: TDateTime;
begin
  lo := Trunc(D) + SessOpenH[Idx] / 24;
  lc := Trunc(D) + SessCloseH[Idx] / 24;
  OpenU := lo - ZoneOffsetH(Idx, lo) / 24;
  CloseU := lc - ZoneOffsetH(Idx, lc) / 24;
end;

function GetSessState(Idx: Integer; NowU: TDateTime): TSessState;
var d: Integer; o, c, bestO, bestC: TDateTime; dow: Word;
begin
  FillChar(Result, SizeOf(Result), 0);
  bestO := 0; bestC := 0;
  for d := -2 to 4 do
  begin
    dow := DayOfTheWeek(Trunc(NowU) + d);
    if dow >= 6 then Continue;   { Sabtu & Minggu pasar tutup }
    SessionWindow(Idx, Trunc(NowU) + d, o, c);
    if (NowU >= o) and (NowU < c) then
    begin
      Result.IsOpen := True;
      Result.OpenU := o; Result.CloseU := c;
      Result.NextChange := c;
      Exit;
    end;
    if (o > NowU) and ((bestO = 0) or (o < bestO)) then begin bestO := o; bestC := c; end;
  end;
  Result.OpenU := bestO; Result.CloseU := bestC;
  Result.NextChange := bestO;
end;

function CountdownStr(Sec: Double): string;
var s: Int64;
begin
  if Sec < 0 then Sec := 0;
  s := Round(Sec);
  if s >= 86400 then
    Result := Format('%dh %.2d:%.2d:%.2d', [s div 86400, (s mod 86400) div 3600, (s mod 3600) div 60, s mod 60])
  else
    Result := Format('%.2d:%.2d:%.2d', [s div 3600, (s mod 3600) div 60, s mod 60]);
end;

{ ---------------- Jadwal sesi versi WIB (untuk pesan di bawah grafik) ----------------
  Sydney 05:00-14:00, Tokyo 07:00-16:00, London 14:00-23:00, New York 19:00-04:00 WIB.
  Persilangan: Sydney-Tokyo 07-14, Tokyo-London 14-16, London-New York 19-23. }

const
  PhStart: array[0..7] of Integer = (0, 4, 5, 7, 14, 16, 19, 23);
  PhEnd: array[0..7] of Integer = (4, 5, 7, 14, 16, 19, 23, 24);
  PhName: array[0..7] of string = (
    'SESI NEW YORK', 'JEDA / ROLLOVER', 'SESI SYDNEY', 'SESI ASIA (SYDNEY + TOKYO)',
    'LONDON OPEN (TOKYO + LONDON)', 'SESI LONDON', 'OVERLAP LONDON - NEW YORK', 'SESI NEW YORK');
  PhSess: array[0..7] of string = (
    'New York 19:00-04:00', 'Semua sesi utama tutup', 'Sydney 05:00-14:00',
    'Sydney 05:00-14:00 + Tokyo 07:00-16:00', 'Tokyo 07:00-16:00 + London 14:00-23:00',
    'London 14:00-23:00', 'London 14:00-23:00 + New York 19:00-04:00', 'New York 19:00-04:00');
  PhCross: array[0..7] of string = (
    'Tidak ada persilangan - sisa sesi New York sampai 04:00',
    'Tidak ada persilangan - pergantian hari broker (04:00-05:00)',
    'Belum ada persilangan - persilangan Sydney-Tokyo mulai 07:00',
    'Persilangan Sydney-Tokyo 07:00-14:00',
    'Persilangan Tokyo-London 14:00-16:00',
    'Tidak ada persilangan - persilangan London-New York mulai 19:00',
    'Persilangan London-New York 19:00-23:00 (paling volatil)',
    'Tidak ada persilangan - hanya New York sampai 04:00');
  PhSignal: array[0..7] of string = (
    'Lanjutan tren NY lalu melambat; setelah 01:00 sering koreksi / profit taking. Hindari entry baru menjelang 04:00.',
    'Spread melebar & likuiditas tipis. Hindari entry, tunggu Sydney buka.',
    'Pasar sepi, range sempit. Breakout sering palsu; cukup scalping pantulan S/R atau tunggu Tokyo.',
    'Konsolidasi Asia: harga membentuk range (high-low Asia). Buy di support / sell di resistance range; tandai high-low Asia untuk breakout London.',
    'London open: sering fake breakout (sweep high/low Asia) lalu berbalik. Tunggu sweep + CHoCH/BOS di TF kecil, entry searah setelah konfirmasi.',
    'Arah tren harian terbentuk. Ikuti BOS London, entry di pullback ke FVG / order block.',
    'Volume & volatilitas tertinggi (data AS 19:30/20:30). Breakout kuat, sinyal BOS/CHoCH paling valid. Waspada berita high-impact, lebarkan SL.',
    'NY pasca-London: tren lanjut tapi momentum berkurang. Ambil profit, geser SL ke BE; entry hanya dengan konfirmasi kuat.');

function NowWIB: TDateTime;
begin
  Result := NowUTC + 7 / 24;
end;

function WIBWeekend(W: TDateTime): Boolean;
var dow: Word; h: Integer;
begin
  { forex/XAU tutup Sabtu 04:00 WIB s.d. Senin 05:00 WIB }
  dow := DayOfTheWeek(W);
  h := HourOf(W);
  Result := ((dow = 6) and (h >= 4)) or (dow = 7) or ((dow = 1) and (h < 5));
end;

function GetWIBPhase(W: TDateTime): TWIBPhase;
var h, i: Integer;
begin
  if WIBWeekend(W) then
  begin
    Result.Idx := -1;
    Result.Name := 'AKHIR PEKAN - FOREX/XAU TUTUP';
    Result.Sessions := 'Tidak ada sesi (buka lagi Senin 05:00 WIB)';
    Result.Cross := 'Tidak ada persilangan';
    Result.Signal := 'Hanya crypto yang bergerak; awas gap harga XAU saat buka Senin.';
    Result.StartH := 4; Result.EndH := 5;
    Exit;
  end;
  h := HourOf(W);
  for i := 0 to 7 do
    if (h >= PhStart[i]) and (h < PhEnd[i]) then
    begin
      Result.Idx := i;
      Result.Name := PhName[i];
      Result.Sessions := PhSess[i];
      Result.Cross := PhCross[i];
      Result.Signal := PhSignal[i];
      Result.StartH := PhStart[i];
      Result.EndH := PhEnd[i];
      Exit;
    end;
end;

function NextWIBPhaseAt(W: TDateTime): TDateTime;
var p: TWIBPhase; d: TDateTime;
begin
  p := GetWIBPhase(W);
  if p.Idx < 0 then
  begin
    d := Trunc(W);
    while DayOfTheWeek(d) <> 1 do d := d + 1;
    Result := d + 5 / 24;
    Exit;
  end;
  Result := Trunc(W) + p.EndH / 24;
  if p.Idx = 7 then Result := Trunc(W) + 1 + 4 / 24;   { 23:00 -> 04:00 besok }
end;

{ ---------------- Kalender berita ---------------- }

procedure AddEv(var E: TEcoEvents; U: TDateTime; const T, C, I: string; B: Boolean);
var n: Integer;
begin
  n := Length(E);
  SetLength(E, n + 1);
  E[n].TimeU := U; E[n].Title := T; E[n].Country := C; E[n].Impact := I;
  E[n].Forecast := ''; E[n].Previous := '';
  E[n].Alert5 := False; E[n].Alert0 := False; E[n].Builtin := B;
end;

function ETtoUTC(Y, M, D, H, Mi: Integer): TDateTime;
var l: TDateTime;
begin
  l := EncodeDate(Y, M, D) + EncodeTime(H, Mi, 0, 0);
  Result := l - NYOffsetH(l + 5 / 24) / 24;
end;

procedure BuildBuiltinEvents(var E: TEcoEvents);
const
  FOMC2026: array[0..7] of string = ('2026-01-28', '2026-03-18', '2026-04-29', '2026-06-17',
                                     '2026-07-29', '2026-09-16', '2026-10-28', '2026-12-09');
var i, y, m: Integer; d: TDateTime;
begin
  SetLength(E, 0);
  for i := 0 to High(FOMC2026) do
  begin
    y := StrToInt(Copy(FOMC2026[i], 1, 4));
    m := StrToInt(Copy(FOMC2026[i], 6, 2));
    d := EncodeDate(y, m, StrToInt(Copy(FOMC2026[i], 9, 2)));
    AddEv(E, ETtoUTC(y, m, DayOf(d), 14, 0), 'FOMC Keputusan Suku Bunga The Fed', 'USD', 'High', True);
    AddEv(E, ETtoUTC(y, m, DayOf(d), 14, 30), 'FOMC Press Conference (Powell/Ketua Fed)', 'USD', 'High', True);
  end;
  { NFP: Jumat pertama tiap bulan 08:30 ET (perkiraan jadwal BLS) }
  for y := 2026 to 2027 do
    for m := 1 to 12 do
    begin
      d := EncodeDate(y, m, 1);
      while DayOfTheWeek(d) <> 5 do d := d + 1;
      AddEv(E, ETtoUTC(y, m, DayOf(d), 8, 30), 'Non-Farm Payrolls (NFP) - perkiraan jadwal', 'USD', 'High', True);
    end;
end;

function ParseISO(const S: string; out U: TDateTime): Boolean;
var y, mo, d, h, mi, se, oh, om: Integer; sign: Integer;
begin
  Result := False;
  if Length(S) < 19 then Exit;
  y := StrToIntDef(Copy(S, 1, 4), 0); mo := StrToIntDef(Copy(S, 6, 2), 0); d := StrToIntDef(Copy(S, 9, 2), 0);
  h := StrToIntDef(Copy(S, 12, 2), 0); mi := StrToIntDef(Copy(S, 15, 2), 0); se := StrToIntDef(Copy(S, 18, 2), 0);
  if (y = 0) or (mo = 0) or (d = 0) then Exit;
  U := EncodeDate(y, mo, d) + EncodeTime(h, mi, se, 0);
  if Length(S) >= 25 then
  begin
    if S[20] = '-' then sign := -1 else sign := 1;
    oh := StrToIntDef(Copy(S, 21, 2), 0); om := StrToIntDef(Copy(S, 24, 2), 0);
    U := U - sign * (oh + om / 60) / 24;
  end;
  Result := True;
end;

function ParseFFCalendar(const S: string; var E: TEcoEvents): Integer;
var p, q, n: Integer; U: TDateTime; imp, cty: string;
begin
  Result := 0;
  p := 1;
  while True do
  begin
    p := PosEx('{', S, p);
    if p = 0 then Break;
    q := PosEx('}', S, p);
    if q = 0 then Break;
    imp := JStr(S, p, q, 'impact');
    cty := JStr(S, p, q, 'country');
    if ((imp = 'High') or ((imp = 'Medium') and (cty = 'USD'))) and
       ParseISO(JStr(S, p, q, 'date'), U) then
    begin
      n := Length(E);
      SetLength(E, n + 1);
      E[n].TimeU := U;
      E[n].Title := JStr(S, p, q, 'title');
      E[n].Country := cty;
      E[n].Impact := imp;
      E[n].Forecast := JStr(S, p, q, 'forecast');
      E[n].Previous := JStr(S, p, q, 'previous');
      E[n].Alert5 := False; E[n].Alert0 := False; E[n].Builtin := False;
      Inc(Result);
    end;
    p := q + 1;
  end;
end;

procedure LoadUserEvents(const FileName: string; var E: TEcoEvents);
var sl, parts: TStringList; i: Integer; s: string; dt: TDateTime;
begin
  if not FileExists(FileName) then Exit;
  sl := TStringList.Create;
  parts := TStringList.Create;
  try
    sl.LoadFromFile(FileName);
    for i := 0 to sl.Count - 1 do
    begin
      s := Trim(sl[i]);
      if (s = '') or (s[1] = '#') then Continue;
      parts.Clear;
      parts.Text := StringReplace(s, ';', #13#10, [rfReplaceAll]);
      if parts.Count < 2 then Continue;
      { format: YYYY-MM-DD HH:MM;Judul;Impact   (jam lokal komputer) }
      s := Trim(parts[0]);
      if Length(s) < 16 then Continue;
      try
        dt := EncodeDate(StrToInt(Copy(s, 1, 4)), StrToInt(Copy(s, 6, 2)), StrToInt(Copy(s, 9, 2))) +
              EncodeTime(StrToInt(Copy(s, 12, 2)), StrToInt(Copy(s, 15, 2)), 0, 0);
      except
        Continue;
      end;
      if parts.Count >= 3 then
        AddEv(E, dt - LocalOffsetH / 24, Trim(parts[1]), 'USER', Trim(parts[2]), False)
      else
        AddEv(E, dt - LocalOffsetH / 24, Trim(parts[1]), 'USER', 'High', False);
    end;
  finally
    parts.Free;
    sl.Free;
  end;
end;

procedure SortEvents(var E: TEcoEvents);
var i, j: Integer; t: TEcoEvent;
begin
  for i := 1 to High(E) do
  begin
    t := E[i];
    j := i - 1;
    while (j >= 0) and (E[j].TimeU > t.TimeU) do
    begin
      E[j + 1] := E[j];
      Dec(j);
    end;
    E[j + 1] := t;
  end;
end;

function IsAlarmEvent(const Ev: TEcoEvent): Boolean;
var t: string;
begin
  t := UpperCase(Ev.Title);
  Result := (Ev.Impact = 'High') or (Pos('FOMC', t) > 0) or (Pos('NON-FARM', t) > 0) or
            (Pos('NFP', t) > 0) or (Pos('CPI', t) > 0) or (Pos('FEDERAL FUNDS', t) > 0);
end;

function EventImpactText(const Title: string): string;
var t: string;
begin
  t := UpperCase(Title);
  if (Pos('NON-FARM', t) > 0) or (Pos('NFP', t) > 0) or (Pos('EMPLOYMENT CHANGE', t) > 0) or (Pos('ADP', t) > 0) then
    Result := 'Aktual > Forecast = USD kuat -> XAU cenderung TURUN. Aktual < Forecast = XAU NAIK.'
  else if (Pos('UNEMPLOYMENT RATE', t) > 0) then
    Result := 'Pengangguran naik = USD lemah -> XAU NAIK. Turun = XAU TURUN.'
  else if (Pos('CLAIMS', t) > 0) then
    Result := 'Klaim pengangguran tinggi = USD lemah -> XAU NAIK.'
  else if (Pos('CPI', t) > 0) or (Pos('PPI', t) > 0) or (Pos('PCE', t) > 0) or (Pos('INFLATION', t) > 0) then
    Result := 'Inflasi lebih tinggi = suku bunga tetap tinggi -> XAU TURUN. Lebih rendah -> XAU NAIK.'
  else if (Pos('FOMC', t) > 0) or (Pos('FEDERAL FUNDS', t) > 0) or (Pos('FED', t) > 0) or (Pos('POWELL', t) > 0) then
    Result := 'Hawkish (naik/tahan suku bunga) -> XAU TURUN. Dovish (pangkas) -> XAU NAIK. Volatilitas sangat tinggi!'
  else if (Pos('GDP', t) > 0) or (Pos('RETAIL', t) > 0) or (Pos('PMI', t) > 0) or (Pos('ISM', t) > 0) then
    Result := 'Data ekonomi kuat = USD menguat -> XAU TURUN. Lemah -> XAU NAIK.'
  else
    Result := 'Berdampak tinggi: hindari entry 15 menit sebelum & sesudah rilis, lebarkan SL.';
end;

end.
