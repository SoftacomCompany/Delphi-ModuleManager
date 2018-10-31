unit ModuleManager;

interface
uses
  System.SysUtils, System.Generics.Collections, System.Classes, System.TypInfo
  ;
type
  TModule = class
  private
    FInstance: TObject;
    FType: TClass;
    FIsOwner: Boolean;
  public
    constructor Create(AType: TClass; AInstance: TObject = nil;
      AIsOwner: Boolean = true);
    destructor Destroy; override;

    procedure Init; virtual;
    procedure Update(AInstance: TObject = nil); virtual;
    procedure Remove; virtual;

    function IsAlive: Boolean;
    function GetInstance: TObject;
    function GetIInstance: IInterface; virtual;

    property ClassType: TClass read FType;
    property IsOwner: Boolean read FIsOwner write FIsOwner;
  end;

  TModuleClass = class of TModule;

  TComponentModule = class(TModule)
  public
    procedure Init; override;
  end;

  TInterfacedModule = class(TModule)
  private
    FIInstance: IInterface;
  public
    procedure Init; override;
    procedure Update(AInstance: TObject = nil); override;
    procedure Remove; override;
    function GetIInstance: IInterface; override;
  end;

  TModuleFakeHelper = record
  public
    class function ModuleByType(AType: TClass): TModuleClass; static;
  end;

  TInterfaceFakeHelper = record
  public
    class function Guid<T: IInterface>: TGUID; static;
  end;

  TModuleManager = class
	private
		class var FInstance:  TModuleManager;
	private
		// Factory for TModule by TGUID key.
		FModules: TDictionary<TGUID, TModule>;
	public
		// Minimal implementation of Singleton pattern + creating an instance only in case of using.
		class constructor Create;
		class destructor Destroy;
		class property Instance: TModuleManager read FInstance;
	public
		constructor Create;
		destructor Destroy; override;

		procedure RegisterModule(const AServiceGUID: TGUID; const AType: TClass; AInstance: TObject = nil; AIsOwner: Boolean = true); overload;
		procedure RegisterModule<T: IInterface>(const AType: TClass; AInstance: TObject = nil; AIsOwner: Boolean = true); overload;

		procedure UnregisterModule(const AServiceGUID: TGUID); overload;
		procedure UnregisterModule<T: IInterface>; overload;

		// Forced removal of an instantiated object with a destructor call.
		procedure RemoveModule(const AServiceGUID: TGUID); overload;
		procedure RemoveModule<T: IInterface>; overload;

		// Deleting only references to the instantiated object without calling the destructor.
		procedure RemoveModuleRef(const AServiceGUID: TGUID); overload;
		procedure RemoveModuleRef<T: IInterface>; overload;

		// Replace the current instantiated object.
		procedure UpdateModule(const AServiceGUID: TGUID; AInstance: TObject); overload;
		procedure UpdateModule<T: IInterface>(AInstance: TObject); overload;

		// Direct receiving of the created instantiated object as TObject or T: IInterface.
		function GetModule(const AServiceGUID: TGUID): TObject; overload;
		function GetModule<T: IInterface>: T; overload;
		function GetModule<T: IInterface>(const AServiceGUID: TGUID): T; overload;

		// Check of the type registration in the Manager.
		function SupportsModule(const AServiceGUID: TGUID): Boolean; overload;
		function SupportsModule<T: IInterface>: Boolean; overload;
		function SupportsModule<T: IInterface>(const AServiceGUID: TGUID): Boolean; overload;

		// The previous 2 methods all together.
		function SupportsModule(const AServiceGUID: TGUID; out AService): Boolean; overload;
		function SupportsModule<T: IInterface>(out AService): Boolean; overload;
		function SupportsModule(const AServiceGUID, ACastServiceGUID: TGUID; out AService): Boolean; overload;
		function SupportsModule<T: IInterface>(const ACastServiceGUID: TGUID; out AService): Boolean; overload;

		// Getting a list of all registered types in the Manager.
		function GetAllModules: TArray<TGUID>;
end;
implementation

{ TModuleManager }

constructor TModuleManager.Create;
begin
	inherited;
	FModules := TObjectDictionary<TGUID, TModule>.Create([doOwnsValues]);
end;

destructor TModuleManager.Destroy;
begin
	FreeAndNil(FModules);
	// Need update After and before events.
end;

function TModuleManager.GetAllModules: TArray<TGUID>;
var
	lList: TList<TGUID>;
	lPair: TPair<TGUID, TModule>;
begin
	lList := TList<TGUID>.Create;
	try
		for lPair in FModules do
			if lPair.Value.IsAlive then
				lList.Add(lPair.Key);
		Result := lList.ToArray;
	finally
		FreeAndNil(lList);
	end;
end;

function TModuleManager.GetModule(const AServiceGUID: TGUID): TObject;
begin
	SupportsModule(AServiceGUID, Result);
end;

function TModuleManager.GetModule<T>: T;
begin
	SupportsModule(TInterfaceFakeHelper.Guid<T>, Result);
end;

function TModuleManager.GetModule<T>(const AServiceGUID: TGUID): T;
begin
	SupportsModule(AServiceGUID, Result);
end;

procedure TModuleManager.RegisterModule(const AServiceGUID: TGUID; const AType: TClass; AInstance: TObject; AIsOwner: Boolean);
begin
	FModules.Add(AServiceGUID,
		TModuleFakeHelper.ModuleByType(AType) // Getting the required container class.
		.Create( // Call a base class constructor.
			AType // A class type to manage.
			, AInstance // Existing instance, optional.
			, AIsOwner // Is the life cycle management required ? optional.
		)
	);
end;

procedure TModuleManager.RegisterModule<T>(const AType: TClass; AInstance: TObject; AIsOwner: Boolean);
begin
	RegisterModule(TInterfaceFakeHelper.Guid<T>, AType, AInstance, AIsOwner);
end;

procedure TModuleManager.RemoveModule(const AServiceGUID: TGUID);
begin
	if FModules.ContainsKey(AServiceGUID) then
		FModules.Items[AServiceGUID].Remove;
end;

procedure TModuleManager.RemoveModule<T>;
begin
	RemoveModule(TInterfaceFakeHelper.Guid<T>);
end;

procedure TModuleManager.RemoveModuleRef(const AServiceGUID: TGUID);
begin
	UpdateModule(AServiceGUID, nil);
end;

procedure TModuleManager.RemoveModuleRef<T>;
begin
	UpdateModule<T>(nil);
end;

function TModuleManager.SupportsModule(const AServiceGUID: TGUID; out AService): Boolean;
begin
	Result := SupportsModule(AServiceGUID, AServiceGUID, AService);
end;

function TModuleManager.SupportsModule(const AServiceGUID, ACastServiceGUID: TGUID; out AService): Boolean;
begin
	Result := false;
	Pointer(AService) := nil;
	if FModules.ContainsKey(AServiceGUID) then
		Result := Supports(FModules.Items[AServiceGUID].GetInstance, ACastServiceGUID, AService);
end;

function TModuleManager.SupportsModule<T>(const ACastServiceGUID: TGUID; out AService): Boolean;
begin
	Result := SupportsModule(TInterfaceFakeHelper.Guid<T>, ACastServiceGUID, AService);
end;

function TModuleManager.SupportsModule<T>(out AService): Boolean;
begin
	Result := SupportsModule(TInterfaceFakeHelper.Guid<T>, AService);
end;

function TModuleManager.SupportsModule(const AServiceGUID: TGUID): Boolean;
begin
	Result := FModules.ContainsKey(AServiceGUID);
end;

function TModuleManager.SupportsModule<T>(const AServiceGUID: TGUID): Boolean;
begin
	Result := SupportsModule(AServiceGUID) and
		Supports(FModules.Items[AServiceGUID].ClassType, TInterfaceFakeHelper.Guid<T>);
end;

function TModuleManager.SupportsModule<T>: Boolean;
begin
	Result := SupportsModule(TInterfaceFakeHelper.Guid<T>);
end;

procedure TModuleManager.UnregisterModule(const AServiceGUID: TGUID);
begin
	FModules.Remove(AServiceGUID);
end;

procedure TModuleManager.UnregisterModule<T>;
begin
	UnregisterModule(TInterfaceFakeHelper.Guid<T>);
end;

procedure TModuleManager.UpdateModule(const AServiceGUID: TGUID; AInstance: TObject);
begin
	if FModules.ContainsKey(AServiceGUID) then
		FModules.Items[AServiceGUID].Update(AInstance);
end;

procedure TModuleManager.UpdateModule<T>(AInstance: TObject);
begin
	UpdateModule(TInterfaceFakeHelper.Guid<T>, AInstance);
end;

class constructor TModuleManager.Create;
begin
	if (FInstance = nil) then
	begin
		FInstance := TModuleManager.Create;
	end;
end;

class destructor TModuleManager.Destroy;
begin
	FreeAndNil(FInstance);
end;

{ TModule }

constructor TModule.Create(AType: TClass; AInstance: TObject;
  AIsOwner: Boolean);
begin
  FType := AType;
  FInstance := AInstance;
  FIsOwner := AIsOwner;
end;

function TModule.GetIInstance: IInterface;
begin
  Result := nil;
end;

function TModule.GetInstance: TObject;
begin
  Init;
  Result := FInstance;
end;

destructor TModule.Destroy;
begin
    if IsOwner then
      Remove;
  inherited;
end;

procedure TModule.Init;
begin
  if not IsAlive then
    FInstance := FType.Create;
end;

function TModule.IsAlive: Boolean;
begin
  Result := Assigned(FInstance);
end;

procedure TModule.Remove;
begin
  FreeAndNil(FInstance);
end;

procedure TModule.Update(AInstance: TObject);
begin
  FInstance := AInstance;
end;

{ TComponentModule }

procedure TComponentModule.Init;
begin
  if not IsAlive then
    FInstance := TComponentClass(FType).Create(nil);
end;

{ TInterfacedModule }
function TInterfacedModule.GetIInstance: IInterface;
begin
  Init;
  Result := FIInstance;
end;

procedure TInterfacedModule.Init;
begin
  if IsAlive then
    Exit;
  FIInstance := TInterfacedClass(FType).Create;
  FInstance := FIInstance as FType;
end;

procedure TInterfacedModule.Remove;
begin
  FIInstance := nil;
  FInstance := nil;
end;

procedure TInterfacedModule.Update(AInstance: TObject);
var
  lIObj: TInterfacedObject absolute AInstance;
begin
  Assert((not Assigned(AInstance)) or (AInstance is TInterfacedObject)
    ,'Allowed only TInterfacedObject');
  inherited;
  FIInstance := lIObj;
end;

{ TModuleFakeHelper }

class function TModuleFakeHelper.ModuleByType(AType: TClass): TModuleClass;
begin
  if AType.InheritsFrom(TComponent) then
    Exit(TComponentModule);
  if AType.InheritsFrom(TInterfacedObject) then
    Exit(TInterfacedModule);
  Result := TModule;
end;

{ TInterfaceFakeHelper }

class function TInterfaceFakeHelper.Guid<T>: TGUID;
begin
  Result := GetTypeData(TypeInfo(T))^.Guid;
end;

end.


