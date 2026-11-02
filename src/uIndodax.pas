unit uIndodax;

{ Indodax (indodax.com) untuk halaman INDODAX:
  - API key / secret di indodax.ini di folder aplikasi (jangan dibagikan)
  - API privat (TAPI): POST https://indodax.com/tapi, header Key + Sign = HMAC-SHA512(body, secret)
  - getInfo: nama akun, saldo IDR & koin }

interface

uses Windows, SysUtils, Classes, WinInet, Math, StrUtils, uBinance;

function SHA512Hex(const S: string): string;
function HmacSHA512Hex(const Key, Msg: string): string;

procedure IdxLoadKeys(const FileName: string);
procedure IdxSaveKeys(const FileName, AKey, ASecret: string);
function IdxHasKeys: Boolean;
function IdxKeyMasked: string;

{ saldo akun: IDR, daftar koin bersaldo "btc=0.1;eth=2" (tanpa idr), nama pemilik akun }
function IdxGetInfo(out IDR: Double; out Coins, Name, Msg: string): Boolean;

implementation

{$Q-}{$R-}

var
  ApiKey, ApiSecret: string;

{ ---------------- SHA-512 / HMAC ---------------- }

const
  { konstanta K SHA-512 sebagai pasangan 32-bit (hi, lo) supaya aman di Delphi 7 }
  K512: array[0..159] of Cardinal = (
    $428a2f98, $d728ae22, $71374491, $23ef65cd, $b5c0fbcf, $ec4d3b2f, $e9b5dba5, $8189dbbc,
    $3956c25b, $f348b538, $59f111f1, $b605d019, $923f82a4, $af194f9b, $ab1c5ed5, $da6d8118,
    $d807aa98, $a3030242, $12835b01, $45706fbe, $243185be, $4ee4b28c, $550c7dc3, $d5ffb4e2,
    $72be5d74, $f27b896f, $80deb1fe, $3b1696b1, $9bdc06a7, $25c71235, $c19bf174, $cf692694,
    $e49b69c1, $9ef14ad2, $efbe4786, $384f25e3, $0fc19dc6, $8b8cd5b5, $240ca1cc, $77ac9c65,
    $2de92c6f, $592b0275, $4a7484aa, $6ea6e483, $5cb0a9dc, $bd41fbd4, $76f988da, $831153b5,
    $983e5152, $ee66dfab, $a831c66d, $2db43210, $b00327c8, $98fb213f, $bf597fc7, $beef0ee4,
    $c6e00bf3, $3da88fc2, $d5a79147, $930aa725, $06ca6351, $e003826f, $14292967, $0a0e6e70,
    $27b70a85, $46d22ffc, $2e1b2138, $5c26c926, $4d2c6dfc, $5ac42aed, $53380d13, $9d95b3df,
    $650a7354, $8baf63de, $766a0abb, $3c77b2a8, $81c2c92e, $47edaee6, $92722c85, $1482353b,
    $a2bfe8a1, $4cf10364, $a81a664b, $bc423001, $c24b8b70, $d0f89791, $c76c51a3, $0654be30,
    $d192e819, $d6ef5218, $d6990624, $5565a910, $f40e3585, $5771202a, $106aa070, $32bbd1b8,
    $19a4c116, $b8d2d0c8, $1e376c08, $5141ab53, $2748774c, $df8eeb99, $34b0bcb5, $e19b48a8,
    $391c0cb3, $c5c95a63, $4ed8aa4a, $e3418acb, $5b9cca4f, $7763e373, $682e6ff3, $d6b2b8a3,
    $748f82ee, $5defb2fc, $78a5636f, $43172f60, $84c87814, $a1f0ab72, $8cc70208, $1a6439ec,
    $90befffa, $23631e28, $a4506ceb, $de82bde9, $bef9a3f7, $b2c67915, $c67178f2, $e372532b,
    $ca273ece, $ea26619c, $d186b8c7, $21c0c207, $eada7dd6, $cde0eb1e, $f57d4f7f, $ee6ed178,
    $06f067aa, $72176fba, $0a637dc5, $a2c898a6, $113f9804, $bef90dae, $1b710b35, $131c471b,
    $28db77f5, $23047d84, $32caab7b, $40c72493, $3c9ebe0a, $15c9bebc, $431d67c4, $9c100d4c,
    $4cc5d4be, $cb3e42b6, $597f299c, $fc657e2a, $5fcb6fab, $3ad6faec, $6c44198c, $4a475817);

  H512: array[0..15] of Cardinal = (
    $6a09e667, $f3bcc908, $bb67ae85, $84caa73b, $3c6ef372, $fe94f82b, $a54ff53a, $5f1d36f1,
    $510e527f, $ade682d1, $9b05688c, $2b3e6c1f, $1f83d9ab, $fb41bd6b, $5be0cd19, $137e2179);

function Mk(Hi, Lo: Cardinal): Int64;
begin
  Result := (Int64(Hi) shl 32) or Int64(Lo);
end;

function ROR64(x: Int64; n: Integer): Int64;
begin
  Result := (x shr n) or (x shl (64 - n));
end;

{ hasil 64 byte mentah }
function SHA512Raw(const S: string): string;
var
  h: array[0..7] of Int64;
  w: array[0..79] of Int64;
  msg: string;
  i, j, blk: Integer;
  a, b, c, d, e, f, g, hh, s0, s1, t1, t2: Int64;
  bits: Int64;
begin
  for i := 0 to 7 do h[i] := Mk(H512[i * 2], H512[i * 2 + 1]);
  bits := Int64(Length(S)) * 8;
  msg := S + #$80;
  while (Length(msg) mod 128) <> 112 do msg := msg + #0;
  for i := 1 to 8 do msg := msg + #0;   { 64 bit atas panjang pesan = 0 }
  for i := 7 downto 0 do msg := msg + Chr((bits shr (i * 8)) and $FF);
  for blk := 0 to Length(msg) div 128 - 1 do
  begin
    for i := 0 to 15 do
    begin
      w[i] := 0;
      for j := 0 to 7 do
        w[i] := (w[i] shl 8) or Ord(msg[blk * 128 + i * 8 + j + 1]);
    end;
    for i := 16 to 79 do
    begin
      s0 := ROR64(w[i - 15], 1) xor ROR64(w[i - 15], 8) xor (w[i - 15] shr 7);
      s1 := ROR64(w[i - 2], 19) xor ROR64(w[i - 2], 61) xor (w[i - 2] shr 6);
      w[i] := w[i - 16] + s0 + w[i - 7] + s1;
    end;
    a := h[0]; b := h[1]; c := h[2]; d := h[3]; e := h[4]; f := h[5]; g := h[6]; hh := h[7];
    for i := 0 to 79 do
    begin
      s1 := ROR64(e, 14) xor ROR64(e, 18) xor ROR64(e, 41);
      t1 := hh + s1 + ((e and f) xor ((not e) and g)) + Mk(K512[i * 2], K512[i * 2 + 1]) + w[i];
      s0 := ROR64(a, 28) xor ROR64(a, 34) xor ROR64(a, 39);
      t2 := s0 + ((a and b) xor (a and c) xor (b and c));
      hh := g; g := f; f := e; e := d + t1;
      d := c; c := b; b := a; a := t1 + t2;
    end;
    h[0] := h[0] + a; h[1] := h[1] + b; h[2] := h[2] + c; h[3] := h[3] + d;
    h[4] := h[4] + e; h[5] := h[5] + f; h[6] := h[6] + g; h[7] := h[7] + hh;
  end;
  Result := '';
  for i := 0 to 7 do
    for j := 7 downto 0 do
      Result := Result + Chr((h[i] shr (j * 8)) and $FF);
end;

function ToHex(const S: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do Result := Result + LowerCase(IntToHex(Ord(S[i]), 2));
end;

function SHA512Hex(const S: string): string;
begin
  Result := ToHex(SHA512Raw(S));
end;

function HmacSHA512Hex(const Key, Msg: string): string;
var k, ipad, opad: string; i: Integer;
begin
  k := Key;
  if Length(k) > 128 then k := SHA512Raw(k);
  while Length(k) < 128 do k := k + #0;
  SetLength(ipad, 128); SetLength(opad, 128);
  for i := 1 to 128 do
  begin
    ipad[i] := Chr(Ord(k[i]) xor $36);
    opad[i] := Chr(Ord(k[i]) xor $5C);
  end;
  Result := ToHex(SHA512Raw(opad + SHA512Raw(ipad + Msg)));
end;

{ ---------------- kunci API ---------------- }

procedure IdxLoadKeys(const FileName: string);
begin
  ApiKey := ''; ApiSecret := '';
  if not FileExists(FileName) then Exit;
  with TStringList.Create do
  try
    LoadFromFile(FileName);
    ApiKey := Trim(Values['KEY']);
    ApiSecret := Trim(Values['SECRET']);
  finally
    Free;
  end;
end;

procedure IdxSaveKeys(const FileName, AKey, ASecret: string);
begin
  ApiKey := Trim(AKey); ApiSecret := Trim(ASecret);
  with TStringList.Create do
  try
    Values['KEY'] := ApiKey;
    Values['SECRET'] := ApiSecret;
    SaveToFile(FileName);
  finally
    Free;
  end;
end;

function IdxHasKeys: Boolean;
begin
  Result := (ApiKey <> '') and (ApiSecret <> '');
end;

function IdxKeyMasked: string;
begin
  if ApiKey = '' then Result := '(belum diisi)'
  else Result := Copy(ApiKey, 1, 4) + '...' + Copy(ApiKey, Length(ApiKey) - 3, 4);
end;

{ ---------------- HTTP ---------------- }

{ POST body form ke https://indodax.com/tapi dengan header Key & Sign }
function TapiPost(const Body: string; out Data: string): Boolean;
var
  hNet, hCon, hReq: HINTERNET;
  Buf: array[0..16383] of Char;
  n, t: DWORD;
  hdr, part: string;
begin
  Result := False; Data := '';
  hNet := InternetOpen('RecognitoTrading/1.0', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hNet = nil then Exit;
  try
    t := 15000;
    InternetSetOption(hNet, INTERNET_OPTION_CONNECT_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_RECEIVE_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_SEND_TIMEOUT, @t, SizeOf(t));
    hCon := InternetConnect(hNet, 'indodax.com', INTERNET_DEFAULT_HTTPS_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
    if hCon = nil then Exit;
    try
      hReq := HttpOpenRequest(hCon, 'POST', '/tapi', nil, nil, nil,
        INTERNET_FLAG_SECURE or INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_CACHE_WRITE, 0);
      if hReq = nil then Exit;
      try
        hdr := 'Content-Type: application/x-www-form-urlencoded'#13#10 +
               'Key: ' + ApiKey + #13#10 +
               'Sign: ' + HmacSHA512Hex(ApiSecret, Body) + #13#10;
        if not HttpSendRequest(hReq, PChar(hdr), Length(hdr), PChar(Body), Length(Body)) then Exit;
        repeat
          n := 0;
          if not InternetReadFile(hReq, @Buf, SizeOf(Buf), n) then Break;
          if n > 0 then
          begin
            SetString(part, Buf, n);
            Data := Data + part;
          end;
        until n = 0;
        Result := Data <> '';
      finally
        InternetCloseHandle(hReq);
      end;
    finally
      InternetCloseHandle(hCon);
    end;
  finally
    InternetCloseHandle(hNet);
  end;
end;

{ nilai sederhana dari JSON: "name":"value" atau "name":123 }
function JStr(const J, Name: string; From: Integer = 1): string;
var p, q: Integer; s: string;
begin
  Result := '';
  s := Copy(J, From, MaxInt);
  p := Pos('"' + Name + '":', s);
  if p = 0 then Exit;
  Inc(p, Length(Name) + 3);
  if (p <= Length(s)) and (s[p] = '"') then
  begin
    q := p + 1;
    while (q <= Length(s)) and (s[q] <> '"') do Inc(q);
    Result := Copy(s, p + 1, q - p - 1);
  end
  else
  begin
    q := p;
    while (q <= Length(s)) and not (s[q] in [',', '}', ']']) do Inc(q);
    Result := Trim(Copy(s, p, q - p));
  end;
end;

function PF(const S: string): Double;
begin
  Result := StrToFloatDef(StringReplace(S, ',', '.', []), 0);
end;

function NowMs: Int64;
var tz: TTimeZoneInformation; r: DWORD; bias: Integer;
begin
  r := GetTimeZoneInformation(tz);
  bias := tz.Bias;
  if r = TIME_ZONE_ID_DAYLIGHT then bias := bias + tz.DaylightBias;
  Result := Round((Now - EncodeDate(1970, 1, 1)) * 86400000) + Int64(bias) * 60000;
end;

{ panggil method TAPI; Result False + Msg = pesan error Indodax }
function Tapi(const Method, Params: string; out Data, Msg: string): Boolean;
var body: string;
begin
  Result := False; Msg := '';
  if not IdxHasKeys then begin Msg := 'API key Indodax belum diisi'; Exit; end;
  body := 'method=' + Method + '&timestamp=' + IntToStr(NowMs) + '&recvWindow=10000';
  if Params <> '' then body := body + '&' + Params;
  if not TapiPost(body, Data) then
  begin
    Msg := 'tidak bisa terhubung ke indodax.com';
    Exit;
  end;
  if JStr(Data, 'success') <> '1' then
  begin
    Msg := JStr(Data, 'error');
    if Msg = '' then Msg := 'jawaban Indodax tidak dikenal';
    Exit;
  end;
  Result := True;
end;

{ ---------------- Trade API 2.0 (api.indodax.com) ----------------
  key bertanda hubung (mis. XXXX-XXXX-...) memakai API 2.0: header X-APIKEY,
  Sign = HMAC-SHA256(query string, secret), timestamp ms }

function V2Http(const Method, Path, Query: string; out Data: string; out Code: Integer): Boolean;
var
  hNet, hCon, hReq: HINTERNET;
  Buf: array[0..16383] of Char;
  n, c, len, idx, t: DWORD;
  hdr, part: string;
begin
  Result := False; Data := ''; Code := 0;
  hNet := InternetOpen('RecognitoTrading/1.0', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hNet = nil then Exit;
  try
    t := 15000;
    InternetSetOption(hNet, INTERNET_OPTION_CONNECT_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_RECEIVE_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_SEND_TIMEOUT, @t, SizeOf(t));
    hCon := InternetConnect(hNet, 'api.indodax.com', INTERNET_DEFAULT_HTTPS_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
    if hCon = nil then Exit;
    try
      hReq := HttpOpenRequest(hCon, PChar(Method), PChar(Path + '?' + Query), nil, nil, nil,
        INTERNET_FLAG_SECURE or INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_CACHE_WRITE, 0);
      if hReq = nil then Exit;
      try
        hdr := 'Accept: application/json'#13#10 +
               'X-APIKEY: ' + ApiKey + #13#10 +
               'Sign: ' + HmacSHA256Hex(ApiSecret, Query) + #13#10;
        if Method = 'POST' then hdr := hdr + 'Content-Type: application/x-www-form-urlencoded'#13#10;
        if not HttpSendRequest(hReq, PChar(hdr), Length(hdr), nil, 0) then Exit;
        c := 0; len := SizeOf(c); idx := 0;
        HttpQueryInfo(hReq, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER, @c, len, idx);
        Code := c;
        repeat
          n := 0;
          if not InternetReadFile(hReq, @Buf, SizeOf(Buf), n) then Break;
          if n > 0 then
          begin
            SetString(part, Buf, n);
            Data := Data + part;
          end;
        until n = 0;
        Result := Code = 200;
      finally
        InternetCloseHandle(hReq);
      end;
    finally
      InternetCloseHandle(hCon);
    end;
  finally
    InternetCloseHandle(hNet);
  end;
end;

{ selisih jam komputer vs server Indodax (ms) }
function ServerOffsetMs: Int64;
var d, part: string; h, r: HINTERNET; Buf: array[0..4095] of Char; n: DWORD; st: Int64;
begin
  Result := 0;
  h := InternetOpen('RecognitoTrading/1.0', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if h = nil then Exit;
  try
    r := InternetOpenUrl(h, 'https://indodax.com/api/server_time', nil, 0, INTERNET_FLAG_RELOAD, 0);
    if r = nil then Exit;
    try
      d := '';
      repeat
        n := 0;
        if not InternetReadFile(r, @Buf, SizeOf(Buf), n) then Break;
        if n > 0 then begin SetString(part, Buf, n); d := d + part; end;
      until n = 0;
    finally
      InternetCloseHandle(r);
    end;
  finally
    InternetCloseHandle(h);
  end;
  st := StrToInt64Def(JStr(d, 'server_time'), 0);
  if st > 0 then Result := st - NowMs;
end;

function V2Signed(const Method, Path, Params: string; out Data, Msg: string): Boolean;
var q: string; c: Integer;
begin
  Result := False; Msg := '';
  if not IdxHasKeys then begin Msg := 'API key Indodax belum diisi'; Exit; end;
  q := Params;
  if q <> '' then q := q + '&';
  q := q + 'timestamp=' + IntToStr(NowMs + ServerOffsetMs) + '&recvWindow=10000';
  if not V2Http(Method, Path, q, Data, c) then
  begin
    Msg := JStr(Data, 'msg');
    if Msg = '' then Msg := JStr(Data, 'error');
    if Msg = '' then
      if c = 0 then Msg := 'tidak bisa terhubung ke api.indodax.com' else Msg := 'HTTP ' + IntToStr(c);
    Exit;
  end;
  Result := True;
end;

function IdxGetInfo(out IDR: Double; out Coins, Name, Msg: string): Boolean;
var d, asset: string; p: Integer; free, locked: Double;
begin
  IDR := 0; Coins := ''; Name := '';
  Result := V2Signed('GET', '/api/v2/account', 'omitZeroBalances=true', d, Msg);
  if not Result then Exit;
  Name := 'UID ' + JStr(d, 'uid');
  // balances: "asset":"idr","free":"...","locked":"..." per aset
  p := Pos('"asset":"', d);
  while p > 0 do
  begin
    asset := LowerCase(JStr(d, 'asset', p));
    free := PF(JStr(d, 'free', p));
    locked := PF(JStr(d, 'locked', p));
    if asset = 'idr' then IDR := free
    else if free + locked > 0 then
    begin
      if Coins <> '' then Coins := Coins + ';';
      Coins := Coins + asset + '=' + FormatFloat('0.########', free + locked);
    end;
    p := PosEx('"asset":"', d, p + 9);
  end;
end;

end.
