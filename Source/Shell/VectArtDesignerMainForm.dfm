object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'VectArtDesigner'
  ClientHeight = 720
  ClientWidth = 1180
  Color = 1973790
  Constraints.MinHeight = 600
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = 15132390
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  TextHeight = 15
  object pnlShortcutBar: TPanel
    Left = 0
    Top = 0
    Width = 1180
    Height = 42
    Align = alTop
    BevelOuter = bvNone
    Color = 2631720
    ParentBackground = False
    TabOrder = 0
    ExplicitWidth = 1178
    object lblShortcutItems: TLabel
      Left = 0
      Top = 0
      Width = 228
      Height = 15
      Align = alClient
      Caption = 'Shortcuts:  New   Open   Save   Undo   Redo'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
  end
  object pnlStatusBar: TPanel
    Left = 0
    Top = 696
    Width = 1180
    Height = 24
    Align = alBottom
    BevelOuter = bvNone
    Color = 2236962
    ParentBackground = False
    TabOrder = 1
    ExplicitTop = 688
    ExplicitWidth = 1178
    object lblStatus: TLabel
      Left = 0
      Top = 0
      Width = 144
      Height = 15
      Align = alClient
      Caption = 'Ready   Canvas: 1920 x 1080'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
  end
  object pnlWorkspace: TPanel
    Left = 0
    Top = 42
    Width = 1180
    Height = 654
    Align = alClient
    BevelOuter = bvNone
    Color = 1710618
    ParentBackground = False
    TabOrder = 2
    ExplicitWidth = 1178
    ExplicitHeight = 616
    object splLeftRegion: TSplitter
      Left = 286
      Top = 0
      Width = 5
      Height = 654
      Color = 3815994
      ParentColor = False
    end
    object splRightRegion: TSplitter
      Left = 885
      Top = 0
      Width = 5
      Height = 654
      Align = alRight
      Color = 3815994
      ParentColor = False
    end
    object pnlLeftDockArea: TPanel
      Left = 0
      Top = 0
      Width = 286
      Height = 654
      Align = alLeft
      BevelOuter = bvNone
      Color = 2171169
      ParentBackground = False
      TabOrder = 0
      ExplicitHeight = 616
    end
    object pnlRightDockArea: TPanel
      Left = 890
      Top = 0
      Width = 290
      Height = 654
      Align = alRight
      BevelOuter = bvNone
      Color = 2171169
      ParentBackground = False
      TabOrder = 1
      ExplicitLeft = 888
      ExplicitHeight = 616
    end
    object pnlEditorHost: TPanel
      Left = 291
      Top = 0
      Width = 594
      Height = 654
      Align = alClient
      BevelOuter = bvNone
      Color = 1184274
      ParentBackground = False
      TabOrder = 2
      ExplicitWidth = 592
      ExplicitHeight = 616
    end
    object pnlLeftDropTarget: TPanel
      Left = 0
      Top = 0
      Width = 64
      Height = 654
      BevelOuter = bvNone
      Caption = 'Dock Left'
      Color = 3156516
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentBackground = False
      ParentFont = False
      TabOrder = 3
      Visible = False
    end
    object pnlRightDropTarget: TPanel
      Left = 1116
      Top = 0
      Width = 64
      Height = 654
      BevelOuter = bvNone
      Caption = 'Dock Right'
      Color = 3156516
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentBackground = False
      ParentFont = False
      TabOrder = 4
      Visible = False
    end
  end
end
