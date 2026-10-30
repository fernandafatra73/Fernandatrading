unit uMF;

{ Deklarasi Media Foundation (mfapi.h / mfobjects.h / mfreadwrite.h) untuk Delphi 7,
  dimuat dinamis (aplikasi tetap jalan di Windows tanpa Media Foundation).
  Dipakai perekam layar (uRec) dan kamera CCTV (uCctv). }

interface

uses Windows, SysUtils, Classes;

type
  IMFMediaBuffer = interface(IUnknown)
    ['{045FA593-8799-42B8-BC8D-8968C6453507}']
    function Lock(out ppbBuffer: Pointer; pcbMaxLength, pcbCurrentLength: PDWORD): HResult; stdcall;
    function Unlock: HResult; stdcall;
    function GetCurrentLength(out pcbCurrentLength: DWORD): HResult; stdcall;
    function SetCurrentLength(cbCurrentLength: DWORD): HResult; stdcall;
    function GetMaxLength(out pcbMaxLength: DWORD): HResult; stdcall;
  end;

  IMFAttributes = interface(IUnknown)
    ['{2CD2D921-C447-44A7-A13C-4ADABFC247E3}']
    function GetItem(const guidKey: TGUID; pValue: Pointer): HResult; stdcall;
    function GetItemType(const guidKey: TGUID; out pType: DWORD): HResult; stdcall;
    function CompareItem(const guidKey: TGUID; Value: Pointer; out pbResult: BOOL): HResult; stdcall;
    function Compare(pTheirs: IUnknown; MatchType: DWORD; out pbResult: BOOL): HResult; stdcall;
    function GetUINT32(const guidKey: TGUID; out punValue: DWORD): HResult; stdcall;
    function GetUINT64(const guidKey: TGUID; out punValue: Int64): HResult; stdcall;
    function GetDouble(const guidKey: TGUID; out pfValue: Double): HResult; stdcall;
    function GetGUID(const guidKey: TGUID; out pguidValue: TGUID): HResult; stdcall;
    function GetStringLength(const guidKey: TGUID; out pcchLength: DWORD): HResult; stdcall;
    function GetString(const guidKey: TGUID; pwszValue: PWideChar; cchBufSize: DWORD; pcchLength: PDWORD): HResult; stdcall;
    function GetAllocatedString(const guidKey: TGUID; out ppwszValue: PWideChar; out pcchLength: DWORD): HResult; stdcall;
    function GetBlobSize(const guidKey: TGUID; out pcbBlobSize: DWORD): HResult; stdcall;
    function GetBlob(const guidKey: TGUID; pBuf: Pointer; cbBufSize: DWORD; pcbBlobSize: PDWORD): HResult; stdcall;
    function GetAllocatedBlob(const guidKey: TGUID; out ppBuf: Pointer; out pcbSize: DWORD): HResult; stdcall;
    function GetUnknown(const guidKey: TGUID; const riid: TGUID; out ppv): HResult; stdcall;
    function SetItem(const guidKey: TGUID; Value: Pointer): HResult; stdcall;
    function DeleteItem(const guidKey: TGUID): HResult; stdcall;
    function DeleteAllItems: HResult; stdcall;
    function SetUINT32(const guidKey: TGUID; unValue: DWORD): HResult; stdcall;
    function SetUINT64(const guidKey: TGUID; unValue: Int64): HResult; stdcall;
    function SetDouble(const guidKey: TGUID; fValue: Double): HResult; stdcall;
    function SetGUID(const guidKey: TGUID; const guidValue: TGUID): HResult; stdcall;
    function SetString(const guidKey: TGUID; wszValue: PWideChar): HResult; stdcall;
    function SetBlob(const guidKey: TGUID; pBuf: Pointer; cbBufSize: DWORD): HResult; stdcall;
    function SetUnknown(const guidKey: TGUID; pUnknown: IUnknown): HResult; stdcall;
    function LockStore: HResult; stdcall;
    function UnlockStore: HResult; stdcall;
    function GetCount(out pcItems: DWORD): HResult; stdcall;
    function GetItemByIndex(unIndex: DWORD; out pguidKey: TGUID; pValue: Pointer): HResult; stdcall;
    function CopyAllItems(pDest: IMFAttributes): HResult; stdcall;
  end;

  IMFMediaType = interface(IMFAttributes)
    ['{44AE0FA8-EA31-4109-8D2E-4CAE4997C555}']
  end;

  IMFSample = interface(IMFAttributes)
    ['{C40A00F2-B93A-4D80-AE8C-5A1C634F58E4}']
    function GetSampleFlags(out pdwSampleFlags: DWORD): HResult; stdcall;
    function SetSampleFlags(dwSampleFlags: DWORD): HResult; stdcall;
    function GetSampleTime(out phnsSampleTime: Int64): HResult; stdcall;
    function SetSampleTime(hnsSampleTime: Int64): HResult; stdcall;
    function GetSampleDuration(out phnsSampleDuration: Int64): HResult; stdcall;
    function SetSampleDuration(hnsSampleDuration: Int64): HResult; stdcall;
    function GetBufferCount(out pdwBufferCount: DWORD): HResult; stdcall;
    function GetBufferByIndex(dwIndex: DWORD; out ppBuffer: IMFMediaBuffer): HResult; stdcall;
    function ConvertToContiguousBuffer(out ppBuffer: IMFMediaBuffer): HResult; stdcall;
    function AddBuffer(pBuffer: IMFMediaBuffer): HResult; stdcall;
  end;

  IMFSinkWriter = interface(IUnknown)
    ['{3137F1CD-FE5E-4805-A5D8-FB477448CB3D}']
    function AddStream(pTargetMediaType: IMFMediaType; out pdwStreamIndex: DWORD): HResult; stdcall;
    function SetInputMediaType(dwStreamIndex: DWORD; pInputMediaType: IMFMediaType; pEncodingParameters: IMFAttributes): HResult; stdcall;
    function BeginWriting: HResult; stdcall;
    function WriteSample(dwStreamIndex: DWORD; pSample: IMFSample): HResult; stdcall;
    function SendStreamTick(dwStreamIndex: DWORD; llTimestamp: Int64): HResult; stdcall;
    function PlaceMarker(dwStreamIndex: DWORD; pvContext: Pointer): HResult; stdcall;
    function NotifyEndOfSegment(dwStreamIndex: DWORD): HResult; stdcall;
    function Flush(dwStreamIndex: DWORD): HResult; stdcall;
    function Finalize: HResult; stdcall;
  end;

  TMFStartup = function(Version: ULONG; dwFlags: DWORD): HResult; stdcall;
  TMFShutdown = function: HResult; stdcall;
  TMFCreateMediaType = function(out ppMFType: IMFMediaType): HResult; stdcall;
  TMFCreateSample = function(out ppIMFSample: IMFSample): HResult; stdcall;
  TMFCreateMemoryBuffer = function(cbMaxLength: DWORD; out ppBuffer: IMFMediaBuffer): HResult; stdcall;
  TMFCreateAttributes = function(out ppMFAttributes: IMFAttributes; cInitialSize: UINT): HResult; stdcall;
  TMFCreateSinkWriterFromURL = function(pwszOutputURL: PWideChar; pByteStream: IUnknown;
    pAttributes: IMFAttributes; out ppSinkWriter: IMFSinkWriter): HResult; stdcall;

const
  MF_VERSION = $00020070;
  MFSTARTUP_FULL = 0;
  COINIT_MULTITHREADED_ = 0;

  MF_MT_MAJOR_TYPE: TGUID = '{48EBA18E-F8C9-4687-BF11-0A74C9F96A8F}';
  MF_MT_SUBTYPE: TGUID = '{F7E34C9A-42E8-4714-B74B-CB29D72C35E5}';
  MF_MT_AVG_BITRATE: TGUID = '{20332624-FB0D-4D9E-BD0D-CBF6786C102E}';
  MF_MT_INTERLACE_MODE: TGUID = '{E2724BB8-E676-4806-B4B2-A8D6EFB44CCD}';
  MF_MT_FRAME_SIZE: TGUID = '{1652C33D-D6B2-4012-B834-72030849A37D}';
  MF_MT_FRAME_RATE: TGUID = '{C459A2E8-3D2C-4E44-B132-FEE5156C7BB0}';
  MF_MT_PIXEL_ASPECT_RATIO: TGUID = '{C6376A1E-8D0A-4027-BE45-6D9A0AD39BB6}';
  MF_MT_DEFAULT_STRIDE: TGUID = '{644B4E48-1E02-4516-B0EB-C01CA9D49AC6}';
  MFMediaType_Video: TGUID = '{73646976-0000-0010-8000-00AA00389B71}';
  MFVideoFormat_H264: TGUID = '{34363248-0000-0010-8000-00AA00389B71}';
  MFVideoFormat_RGB32: TGUID = '{00000016-0000-0010-8000-00AA00389B71}';
  CODECAPI_AVEncCommonRateControlMode: TGUID = '{1C0608E9-370C-4710-8A58-CB6181C42423}';
  CODECAPI_AVEncCommonQuality: TGUID = '{FCBF57A3-7EA5-4B0C-9644-69B40C39C391}';
  MFVideoInterlace_Progressive = 2;
  RateControl_Quality = 3;

function CoInitializeEx_(pvReserved: Pointer; coInit: Longint): HResult; stdcall; external 'ole32.dll' name 'CoInitializeEx';
procedure CoUninitialize_; stdcall; external 'ole32.dll' name 'CoUninitialize';

var
  hPlat, hRW: HMODULE;
  MFStartup: TMFStartup;
  MFShutdown: TMFShutdown;
  MFCreateMediaType: TMFCreateMediaType;
  MFCreateSample: TMFCreateSample;
  MFCreateMemoryBuffer: TMFCreateMemoryBuffer;
  MFCreateAttributes: TMFCreateAttributes;
  MFCreateSinkWriterFromURL: TMFCreateSinkWriterFromURL;
  MFLoaded: Integer = 0;   { 0 belum dicoba, 1 ada, -1 tidak ada }


type
  IMFSourceReader = interface(IUnknown)
    ['{70AE66F2-C809-4E4F-8915-BDCB406B7993}']
    function GetStreamSelection(dwStreamIndex: DWORD; out pfSelected: BOOL): HResult; stdcall;
    function SetStreamSelection(dwStreamIndex: DWORD; fSelected: BOOL): HResult; stdcall;
    function GetNativeMediaType(dwStreamIndex, dwMediaTypeIndex: DWORD; out ppMediaType: IMFMediaType): HResult; stdcall;
    function GetCurrentMediaType(dwStreamIndex: DWORD; out ppMediaType: IMFMediaType): HResult; stdcall;
    function SetCurrentMediaType(dwStreamIndex: DWORD; pdwReserved: PDWORD; pMediaType: IMFMediaType): HResult; stdcall;
    function SetCurrentPosition(const guidTimeFormat: TGUID; varPosition: Pointer): HResult; stdcall;
    function ReadSample(dwStreamIndex, dwControlFlags: DWORD; pdwActualStreamIndex, pdwStreamFlags: PDWORD;
      pllTimestamp: PInt64; out ppSample: IMFSample): HResult; stdcall;
    function Flush(dwStreamIndex: DWORD): HResult; stdcall;
  end;

  TMFCreateSourceReaderFromURL = function(pwszURL: PWideChar; pAttributes: IMFAttributes;
    out ppSourceReader: IMFSourceReader): HResult; stdcall;

const
  MF_SOURCE_READER_FIRST_VIDEO_STREAM = $FFFFFFFC;
  MF_SOURCE_READER_ALL_STREAMS = $FFFFFFFE;
  MF_SOURCE_READERF_ERROR = $1;
  MF_SOURCE_READERF_ENDOFSTREAM = $2;
  MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED = $20;
  MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING: TGUID = '{FB394F3D-CCF1-42EE-BBB3-F9B845D5681D}';
  MF_SOURCE_READER_ENABLE_ADVANCED_VIDEO_PROCESSING: TGUID = '{0F81DA2C-B537-4672-A8B2-A681B17307A3}';
  MF_LOW_LATENCY: TGUID = '{9C27891A-ED7A-40E1-88E8-B22727A024EE}';

var
  MFCreateSourceReaderFromURL: TMFCreateSourceReaderFromURL;

function MFAvailable: Boolean;
function Pack64(Hi, Lo: Cardinal): Int64;

implementation

function MFAvailable: Boolean;
begin
  if MFLoaded = 0 then
  begin
    MFLoaded := -1;
    hPlat := LoadLibrary('mfplat.dll');
    hRW := LoadLibrary('mfreadwrite.dll');
    if (hPlat <> 0) and (hRW <> 0) then
    begin
      @MFStartup := GetProcAddress(hPlat, 'MFStartup');
      @MFShutdown := GetProcAddress(hPlat, 'MFShutdown');
      @MFCreateMediaType := GetProcAddress(hPlat, 'MFCreateMediaType');
      @MFCreateSample := GetProcAddress(hPlat, 'MFCreateSample');
      @MFCreateMemoryBuffer := GetProcAddress(hPlat, 'MFCreateMemoryBuffer');
      @MFCreateAttributes := GetProcAddress(hPlat, 'MFCreateAttributes');
      @MFCreateSinkWriterFromURL := GetProcAddress(hRW, 'MFCreateSinkWriterFromURL');
      @MFCreateSourceReaderFromURL := GetProcAddress(hRW, 'MFCreateSourceReaderFromURL');
      if Assigned(MFStartup) and Assigned(MFShutdown) and Assigned(MFCreateMediaType) and
         Assigned(MFCreateSample) and Assigned(MFCreateMemoryBuffer) and Assigned(MFCreateAttributes) and
         Assigned(MFCreateSinkWriterFromURL) then MFLoaded := 1;
    end;
  end;
  Result := MFLoaded = 1;
end;

function Pack64(Hi, Lo: Cardinal): Int64;
begin
  Result := (Int64(Hi) shl 32) or Int64(Lo);
end;

end.