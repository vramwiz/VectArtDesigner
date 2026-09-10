// デザイナーFrame群がホストアプリケーションから受け取る共通サービス境界を提供する。
// Document等は非所有参照とし、UI専用の色履歴だけをContextの寿命で所有する。
unit VectArtDesignerContext;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory,
  VectArtDesignerEditorState, VectArtDesignerColorHistory;

type
  // デザイナーFrameを別アプリケーションへ組み込む際の単一の接続口を表す。
  IVectArtDesignerContext = interface
    ['{4697CD46-87BB-44B1-94B6-C6444D6D11C0}']
    function GetDocument: TVectArtDocument;
    function GetEditHistory: TVectArtEditHistory;
    function GetEditorState: TVectArtEditorState;
    function GetColorHistory: TVectArtColorHistory;
    property Document: TVectArtDocument read GetDocument;
    property EditHistory: TVectArtEditHistory read GetEditHistory;
    property EditorState: TVectArtEditorState read GetEditorState;
    property ColorHistory: TVectArtColorHistory read GetColorHistory;
  end;

  // 既存のDocument、履歴、編集状態をContextとして公開する標準アダプター。
  TVectArtDesignerContext = class(TInterfacedObject, IVectArtDesignerContext)
  private
    FDocument: TVectArtDocument;
    FEditHistory: TVectArtEditHistory;
    FEditorState: TVectArtEditorState;
    FColorHistory: TVectArtColorHistory;
  protected
    function GetDocument: TVectArtDocument;
    function GetEditHistory: TVectArtEditHistory;
    function GetEditorState: TVectArtEditorState;
    function GetColorHistory: TVectArtColorHistory;
  public
    // 渡されたサービスは非所有参照とし、色履歴はContext内で生成する。
    constructor Create(ADocument: TVectArtDocument;
      AEditHistory: TVectArtEditHistory; AEditorState: TVectArtEditorState);
    destructor Destroy; override;
  end;

implementation

constructor TVectArtDesignerContext.Create(ADocument: TVectArtDocument;
  AEditHistory: TVectArtEditHistory; AEditorState: TVectArtEditorState);
begin
  inherited Create;
  FDocument := ADocument;
  FEditHistory := AEditHistory;
  FEditorState := AEditorState;
  FColorHistory := TVectArtColorHistory.Create;
end;

destructor TVectArtDesignerContext.Destroy;
begin
  FColorHistory.Free;
  inherited;
end;

function TVectArtDesignerContext.GetColorHistory: TVectArtColorHistory;
begin
  Result := FColorHistory;
end;

function TVectArtDesignerContext.GetDocument: TVectArtDocument;
begin
  Result := FDocument;
end;

function TVectArtDesignerContext.GetEditHistory: TVectArtEditHistory;
begin
  Result := FEditHistory;
end;

function TVectArtDesignerContext.GetEditorState: TVectArtEditorState;
begin
  Result := FEditorState;
end;

end.
