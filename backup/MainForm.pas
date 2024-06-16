unit MainForm;

interface

uses
  LCLIntf, LCLType, LMessages,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, FileCtrl, ImgList, StdCtrls, ExtCtrls, DateUtils, ComCtrls, Spin;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btnExecute: TButton;
    btnPreview: TButton;
    btnProcess: TButton;
    btnSelect: TButton;
    chkForceChangeDateTime: TCheckBox;
    chkLog: TCheckBox;
    chkSubDirectory: TCheckBox;
    edtOrigin: TEdit;
    il16: TImageList;
    lblOrigin: TLabel;
    mmoLog: TMemo;
    lvDir: TListView;
    pnlTop: TPanel;
    sbStatus: TStatusBar;
    seLevel: TSpinEdit;
    Splitter1: TSplitter;
    procedure btnExecuteClick(Sender: TObject);
    procedure btnPreviewClick(Sender: TObject);
    procedure btnProcessClick(Sender: TObject);
    procedure btnSelectClick(Sender: TObject);
    procedure chkLogChange(Sender: TObject);
    procedure chkSubDirectoryChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lvDirCustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: boolean);
    procedure pnlTopClick(Sender: TObject);
  private
    { Private declarations }

    FPath: string;
    FRootDateTime: TDateTime;
  public
    { Public declarations }
    MinDateTime: TDateTime;
    procedure RecursiveFixFolder(Directory: string);
    procedure Preview(Directory: string; Level: integer);
    procedure EnableMainControls(Value: boolean);
  end;

var
  frmMain: TfrmMain;

const
  ERROR_NO_DIR = 'Select a folder before proceeding with the select operation!';
  ERROR_NO_COUNT = 'There are no folders to perform this function!';
  REQUEST_MSG =
    'Are you sure you want to set the dates of the folders as those of the files found inside it?'#13#1'It will never be possible to go back!';
  S_DIFFERENT = 'DIFFERENT';
  S_OK = 'OK';

implementation


{$R *.lfm}


const
  FILE_WRITE_ATTRIBUTES = $0100;

function SetFolderCreationTime(const FolderPath: string;
  const NewCreationTime: TDateTime): boolean;
var
  Handle: THandle;
  FileTime, LocalFileTime: TFileTime;
  SystemTime: TSystemTime;
  SecurityAttributes: TSecurityAttributes;
begin
  Result := False;

  // Convert the TDateTime to TSystemTime
  DateTimeToSystemTime(NewCreationTime, SystemTime);

  // Convert TSystemTime to TFileTime
  SystemTimeToFileTime(SystemTime, LocalFileTime);
  LocalFileTimeToFileTime(LocalFileTime, FileTime);

  // Set up security attributes
  SecurityAttributes.nLength := SizeOf(TSecurityAttributes);
  SecurityAttributes.lpSecurityDescriptor := nil;
  SecurityAttributes.bInheritHandle := True;

  // Open the directory
  Handle := CreateFile(PChar(FolderPath), GENERIC_WRITE, FILE_SHARE_READ or
    FILE_SHARE_WRITE or FILE_SHARE_DELETE, @SecurityAttributes,
    OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);

  if Handle = INVALID_HANDLE_VALUE then
    Exit;

  try
    // Set the creation time
    //  if SetFileTime(Handle, @FileTime, @FileTime, @FileTime) then
    if SetFileTime(Handle, nil, nil, @FileTime) then
      Result := True;
  finally
    // Close the handle
    FileClose(Handle); { *Converted from CloseHandle* }
  end;
end;

procedure Debug(Value: string);
begin
  if not frmMain.chkLog.Checked then Exit;
  OutputDebugString(PChar(Value));

  frmMain.mmoLog.Lines.Add(Value);
  SendMessage(frmMain.mmoLog.Handle, EM_LINESCROLL, 0, frmMain.mmoLog.Lines.Count);
end;


procedure SetPanelText(Text: string; PanelIndex: integer = 0; const Space: integer = 50);
var
  W: integer;
begin
  with frmMain.sbStatus do
  begin
    Canvas.Font := frmMain.sbStatus.Font;
    Panels[PanelIndex].Text := Text;
    W := Canvas.TextWidth(Text + ' ');
    Panels[PanelIndex].Width := W + 20 + Space;
    Update;
  end;
end;


function GetFolderDate(Folder: string): TDateTime;
var
  Rec: TSearchRec;
  Found: integer;
  Date: TDateTime;
begin
  Folder := ExcludeTrailingPathDelimiter(Folder);
  Result := 0;
  Found := FindFirst(Folder, faDirectory, Rec);
  try
    if Found = 0 then
    begin
      Date := Rec.TimeStamp; //FileDateToDateTime(Rec.Time);;
      Result := Date;
    end;
  finally
    FindClose(Rec);
  end;
end;


function GetFileMaxDate(Folder: string): TDateTime;
var
  Search: TSearchRec;
  MaxDateTime: TDateTime;
begin
  Folder := ExcludeTrailingPathDelimiter(Folder);
  MaxDateTime := EncodeDateTime(1901, 1, 1, 1, 1, 1, 1);
  if FindFirst(Folder + '\*.*', $23, search) = 0 then
  begin
    repeat
      if (search.TimeStamp > MaxDateTime) then
        MaxDateTime := Search.TimeStamp;
    until FindNext(search) <> 0;

  end;
  FindClose(search);
  if (YearOf(MaxDateTime) = 1901) then MaxDateTime := GetFolderDate(Folder);

  Result := MaxDateTime;
end;


procedure TfrmMain.EnableMainControls(Value: boolean);
begin
  pnlTop.Enabled := Value;
  lvDir.Enabled := Value;
end;

procedure TfrmMain.Preview(Directory: string; Level: integer);
var
  search: TSearchRec;
  FolderDateTime: TDateTime;
  MaxDateTime: TDateTime;
  Item: TListItem;
begin
  if (seLevel.Value > 0) and (Level > seLevel.Value) then exit;

  Directory := IncludeTrailingBackslash(Directory);
  Item := lvDir.Items.Add;
  Item.Caption := Directory.Substring(FPath.Length);
  Item.ImageIndex := 0;
  Item.StateIndex := 0;

  Directory := ExcludeTrailingPathDelimiter(Directory);

  Debug('PREVIEW: ' + Directory);
  SetPanelText(Item.Caption);

  FolderDateTime := GetFolderDate(Directory);
  MaxDateTime := GetFileMaxDate(Directory);

  if (YearOf(FolderDateTime) = 1901) then FolderDateTime := Now;
  if (YearOf(MaxDateTime) = 1901) then MaxDateTime := FRootDateTime;


  Item.SubItems.Add(DateTimeToStr(FolderDateTime));
  Item.SubItems.Add(DateTimeToStr(MaxDateTime));

  if (FolderDateTime > MaxDateTime) or (FolderDateTime = MinDateTime) then
    Item.SubItems.Add(S_DIFFERENT)
  else
    Item.SubItems.Add(S_OK);

  Item.SubItems.Add(Level.ToString);

  if chkSubDirectory.Checked then
  begin
    if FindFirst(Directory + '\*.*', faDirectory, search) = 0 then
    begin
      repeat
        if ((search.Attr and faDirectory) = faDirectory) and (search.Name[1] <> '.') then
        begin
          Preview(Directory + '\' + search.Name + '\', Level + 1);
        end;

      until FindNext(search) <> 0;

    end;
    FindClose(search);
  end;

end;

procedure TfrmMain.RecursiveFixFolder(Directory: string);
var
  search: TSearchRec;
  FolderDateTime: TDateTime;
  MaxDateTime: TDateTime;
  Item: TListItem;
begin

  Directory := IncludeTrailingBackslash(Directory);
  Item := lvDir.Items.Add;
  Item.Caption := Directory.Substring(FPath.Length);
  Item.ImageIndex := 0;
  Item.StateIndex := 0;

  Directory := ExcludeTrailingPathDelimiter(Directory);

  Debug('FIX: ' + Directory);
  SetPanelText(Item.Caption);

  FolderDateTime := GetFolderDate(Directory);
  MaxDateTime := GetFileMaxDate(Directory);

  if (YearOf(FolderDateTime) = 1901) then FolderDateTime := Now;
  if (YearOf(MaxDateTime) = 1901) then MaxDateTime := FRootDateTime;


  Item.SubItems.Add(DateTimeToStr(FolderDateTime));
  Item.SubItems.Add(DateTimeToStr(MaxDateTime));

  if (FolderDateTime > MaxDateTime) or (FolderDateTime = MinDateTime) then
    Item.SubItems.Add(S_DIFFERENT)
  else
    Item.SubItems.Add(S_OK);



  if chkSubDirectory.Checked then
    if FindFirst(Directory + '\*.*', faDirectory, search) = 0 then
    begin
      repeat
        if ((search.Attr and faDirectory) = faDirectory) and
          (search.Name[1] <> '.') then
          Preview(Directory + '\' + search.Name + '\', 0);
      until FindNext(search) <> 0;

    end;

  FindClose(search);

  if (FolderDateTime > MaxDateTime) or (chkForceChangeDateTime.Checked) then
    // if MessageDlg('Du you want set file datetime?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    if SetFolderCreationTime(Directory, MaxDateTime) then
      Debug('Modify time updated successfully.')
    else
      Debug('Failed to update modify time.');

    FolderDateTime := GetFolderDate(Directory);
  end;

  Debug('------------------------------------------');
  Debug('');
end;

procedure TfrmMain.btnProcessClick(Sender: TObject);
begin
  lvDir.Items.BeginUpdate;
  lvDir.Items.Clear;

  FPath := ExcludeTrailingPathDelimiter(edtOrigin.Text);
  FRootDateTime := GetFileMaxDate(FPath);
  Debug('Max File DateTime in Root: ' + DateTimeToStr(FRootDateTime));


  RecursiveFixFolder(FPath);

  lvDir.Items.EndUpdate;

  SetPanelText('Folder Found: ' + lvDir.Items.Count.ToString);
end;

procedure TfrmMain.btnPreviewClick(Sender: TObject);
begin

  FPath := ExcludeTrailingPathDelimiter(edtOrigin.Text);
  if not DirectoryExists(FPath) then
  begin
    MessageDlg(ERROR_NO_DIR, mtError, [mbOK], 0);
    SetPanelText(ERROR_NO_DIR);
    Exit;
  end;

  EnableMainControls(False);

  lvDir.Items.BeginUpdate;
  lvDir.Items.Clear;

  FRootDateTime := GetFileMaxDate(FPath);
  Debug('Max File DateTime in Root: ' + DateTimeToStr(FRootDateTime));

  Preview(FPath, 0);

  SetPanelText('Folder Found: ' + lvDir.Items.Count.ToString);

  lvDir.Items.EndUpdate;

  EnableMainControls(True);
end;

procedure TfrmMain.btnExecuteClick(Sender: TObject);
var
  Item: TListItem;
  Path: string;
  DateFolder: TDateTime;
  DateFile: TDateTime;
begin
  mmoLog.Clear;


  FPath := ExcludeTrailingPathDelimiter(edtOrigin.Text);
  if not DirectoryExists(FPath) then
  begin
    MessageDlg('There are no folders to do this', mtError, [mbOK], 0);
    SetPanelText(ERROR_NO_DIR);
    Exit;
  end;

  if lvDir.Items.Count = 0 then
  begin
    MessageDlg(ERROR_NO_COUNT, mtError, [mbOK], 0);
    SetPanelText(ERROR_NO_COUNT);
    Exit;
  end;


  if MessageDlg(REQUEST_MSG, mtWarning, [mbYes, mbNo], 0) = mrNo then  Exit;

  EnableMainControls(False);

  lvDir.Items.BeginUpdate;
  for  Item in lvDir.Items do
  begin
    Path := FPath + Item.Caption;
    DateFolder := StrToDateTime(Item.SubItems[0]);
    DateFile := StrToDateTime(Item.SubItems[1]);
    Path := ExcludeTrailingPathDelimiter(Path);


    SetPanelText(Format('Fix Folder %d of %d', [Item.Index + 1, lvDir.Items.Count]));
    Debug(Path);
    Debug(DateTimeToStr(DateFolder));
    Debug(DateTimeToStr(DateFile));


    if (DateFolder > DateFile) or (chkForceChangeDateTime.Checked) then
    begin
      if SetFolderCreationTime(Path, DateFile) then
      begin
        Debug('Modify time updated successfully.');
        Item.SubItems[2] := 'CHANGED';
      end
      else
      begin
        Debug('Failed to update modify time.');
        Item.SubItems[2] := 'ERROR';
      end;

      DateFolder := GetFolderDate(Path);
    end;

    Debug('');
  end;

  SetPanelText('The operation ended successfully!');
  lvDir.Items.EndUpdate;

  EnableMainControls(True);
end;

procedure TfrmMain.btnSelectClick(Sender: TObject);
var
  Folder: string;
begin

  Folder := edtOrigin.Text;

  if not SelectDirectory('Select a directory', '', Folder) then
    Exit;




  edtOrigin.Text := Folder;
end;

procedure TfrmMain.chkLogChange(Sender: TObject);
begin
  mmoLog.Visible := chkLog.Checked;
end;

procedure TfrmMain.chkSubDirectoryChange(Sender: TObject);
begin
  seLevel.Enabled := chkSubDirectory.Checked;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  MinDateTime := EncodeDateTime(1901, 1, 1, 1, 1, 1, 1);
end;

procedure TfrmMain.lvDirCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: boolean);
begin
  if Item.SubItems[2] = S_DIFFERENT then
    lvDir.Canvas.Brush.Color := $CCCCFF
  else
    lvDir.Canvas.Brush.Color := clWindow;
end;

procedure TfrmMain.pnlTopClick(Sender: TObject);
begin

end;

end.
