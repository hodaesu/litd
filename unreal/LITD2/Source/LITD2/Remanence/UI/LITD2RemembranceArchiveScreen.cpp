#include "Remanence/UI/LITD2RemembranceArchiveScreen.h"

#include "Brushes/SlateColorBrush.h"
#include "Dom/JsonObject.h"
#include "InputCoreTypes.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Remanence/LITD2RemembranceDataAssets.h"
#include "Remanence/LITD2RemembranceSubsystem.h"
#include "Rendering/DrawElementTypes.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Styling/CoreStyle.h"
#include "Widgets/Layout/SBox.h"

namespace
{
    static const FSlateColorBrush SolidBrush(FLinearColor::White);

    ELITD2RemembranceDiscoveryState ParseDiscoveryState(const FString& Value)
    {
        if (Value == TEXT("Trace")) return ELITD2RemembranceDiscoveryState::Trace;
        if (Value == TEXT("Documented")) return ELITD2RemembranceDiscoveryState::Documented;
        if (Value == TEXT("Reconstructed")) return ELITD2RemembranceDiscoveryState::Reconstructed;
        if (Value == TEXT("Contested")) return ELITD2RemembranceDiscoveryState::Contested;
        return ELITD2RemembranceDiscoveryState::Unknown;
    }

    ELITD2UnlockType ParseUnlockType(const FString& Value)
    {
        if (Value == TEXT("GameplayFeature")) return ELITD2UnlockType::GameplayFeature;
        if (Value == TEXT("Battle")) return ELITD2UnlockType::Battle;
        if (Value == TEXT("Lore")) return ELITD2UnlockType::Lore;
        if (Value == TEXT("Equipment")) return ELITD2UnlockType::Equipment;
        if (Value == TEXT("SkillVariant")) return ELITD2UnlockType::SkillVariant;
        if (Value == TEXT("Oath")) return ELITD2UnlockType::Oath;
        if (Value == TEXT("Preparation")) return ELITD2UnlockType::Preparation;
        if (Value == TEXT("EnemyKnowledge")) return ELITD2UnlockType::EnemyKnowledge;
        if (Value == TEXT("LogisticsCapacity")) return ELITD2UnlockType::LogisticsCapacity;
        return ELITD2UnlockType::None;
    }

    void ReadNameArray(const TSharedPtr<FJsonObject>& Object, const TCHAR* Field, TArray<FName>& OutValues)
    {
        OutValues.Reset();
        if (!Object.IsValid() || !Object->HasField(Field))
        {
            return;
        }

        for (const TSharedPtr<FJsonValue>& Value : Object->GetArrayField(Field))
        {
            FString Text;
            if (Value.IsValid() && Value->TryGetString(Text))
            {
                OutValues.Add(FName(*Text));
            }
        }
    }

    TArray<FString> WrapWords(const FString& Input, int32 MaxCharacters)
    {
        TArray<FString> Words;
        Input.ParseIntoArrayWS(Words);

        TArray<FString> Lines;
        FString Current;
        for (const FString& Word : Words)
        {
            const FString Candidate = Current.IsEmpty() ? Word : Current + TEXT(" ") + Word;
            if (Candidate.Len() > MaxCharacters && !Current.IsEmpty())
            {
                Lines.Add(Current);
                Current = Word;
            }
            else
            {
                Current = Candidate;
            }
        }
        if (!Current.IsEmpty())
        {
            Lines.Add(Current);
        }
        return Lines;
    }

    FPaintGeometry PaintGeometryAt(const FGeometry& Geometry, const FVector2D& Position, const FVector2D& Size)
    {
        return Geometry.ToPaintGeometry(Size, FSlateLayoutTransform(Position));
    }

    void DrawSolidBox(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Position,
        const FVector2D& Size,
        const FLinearColor& Color)
    {
        FSlateDrawElement::MakeBox(
            OutDrawElements,
            Layer,
            PaintGeometryAt(Geometry, Position, Size),
            &SolidBrush,
            ESlateDrawEffect::None,
            Color);
    }

    void DrawTextLine(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Position,
        const FString& Text,
        int32 FontSize,
        const FLinearColor& Color,
        bool bBold = false)
    {
        const FSlateFontInfo Font = FCoreStyle::GetDefaultFontStyle(bBold ? TEXT("Bold") : TEXT("Regular"), FontSize);
        FSlateDrawElement::MakeText(
            OutDrawElements,
            Layer,
            PaintGeometryAt(Geometry, Position, FVector2D(1.0, 1.0)),
            Text,
            Font,
            ESlateDrawEffect::None,
            Color);
    }

    void DrawLine(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Start,
        const FVector2D& End,
        const FLinearColor& Color,
        float Thickness)
    {
        TArray<FVector2f> Points;
        Points.Add(FVector2f(Start));
        Points.Add(FVector2f(End));
        FSlateDrawElement::MakeLines(
            OutDrawElements,
            Layer,
            Geometry.ToPaintGeometry(),
            Points,
            ESlateDrawEffect::None,
            Color,
            true,
            Thickness);
    }

    void DrawDashedLine(
        FSlateWindowElementList& OutDrawElements,
        int32 Layer,
        const FGeometry& Geometry,
        const FVector2D& Start,
        const FVector2D& End,
        const FLinearColor& Color,
        float Thickness)
    {
        constexpr int32 SegmentCount = 15;
        for (int32 Segment = 0; Segment < SegmentCount; Segment += 2)
        {
            const double A = static_cast<double>(Segment) / SegmentCount;
            const double B = static_cast<double>(FMath::Min(Segment + 1, SegmentCount)) / SegmentCount;
            DrawLine(
                OutDrawElements,
                Layer,
                Geometry,
                FMath::Lerp(Start, End, A),
                FMath::Lerp(Start, End, B),
                Color,
                Thickness);
        }
    }
}

TSharedRef<SWidget> ULITD2RemembranceArchiveScreen::RebuildWidget()
{
    return SNew(SBox);
}

void ULITD2RemembranceArchiveScreen::NativeConstruct()
{
    Super::NativeConstruct();

    if (UGameInstance* GameInstance = GetGameInstance())
    {
        RemembranceSubsystem = GameInstance->GetSubsystem<ULITD2RemembranceSubsystem>();
    }

    ReloadArchive();
}

bool ULITD2RemembranceArchiveScreen::ReloadArchive()
{
    Nodes.Reset();
    Reconstructions.Reset();
    NodeIndexById.Reset();

    const FString SeedPath = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), SeedRelativePath));
    if (!LoadSeedJson(SeedPath))
    {
        return false;
    }

    const FString LayoutPath = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), LayoutRelativePath));
    if (!LoadLayoutJson(LayoutPath))
    {
        BuildFallbackLayout();
    }

    InitializeAuthoringDefaults();

    if (SelectedEntryId.IsNone() || !NodeIndexById.Contains(SelectedEntryId))
    {
        for (const FLITD2ArchiveVisualNode& Node : Nodes)
        {
            if (IsNodeVisible(Node))
            {
                SelectedEntryId = Node.EntryId;
                break;
            }
        }
    }

    InvalidateLayoutAndVolatility();
    return true;
}

bool ULITD2RemembranceArchiveScreen::LoadSeedJson(const FString& AbsolutePath)
{
    FString JsonText;
    if (!FFileHelper::LoadFileToString(JsonText, *AbsolutePath))
    {
        UE_LOG(LogTemp, Error, TEXT("LITD2 Remanence UI: impossible de lire %s"), *AbsolutePath);
        return false;
    }

    TSharedPtr<FJsonObject> Root;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonText);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
    {
        UE_LOG(LogTemp, Error, TEXT("LITD2 Remanence UI: JSON invalide %s"), *AbsolutePath);
        return false;
    }

    TSet<FName> InitiallyVisible;
    if (Root->HasField(TEXT("initial_archive")))
    {
        const TSharedPtr<FJsonObject> InitialArchive = Root->GetObjectField(TEXT("initial_archive"));
        if (InitialArchive.IsValid() && InitialArchive->HasField(TEXT("visible_entry_ids")))
        {
            for (const TSharedPtr<FJsonValue>& Value : InitialArchive->GetArrayField(TEXT("visible_entry_ids")))
            {
                FString Id;
                if (Value.IsValid() && Value->TryGetString(Id))
                {
                    InitiallyVisible.Add(FName(*Id));
                }
            }
        }
    }

    for (const TSharedPtr<FJsonValue>& Value : Root->GetArrayField(TEXT("entries")))
    {
        const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
        if (!Object.IsValid())
        {
            continue;
        }

        FLITD2ArchiveVisualNode Node;
        Node.EntryId = FName(*Object->GetStringField(TEXT("entry_id")));
        Node.Title = FText::FromString(Object->GetStringField(TEXT("title")));
        Node.Description = FText::FromString(Object->GetStringField(TEXT("description")));
        Node.Category = Object->GetStringField(TEXT("category"));
        Node.Reliability = Object->GetStringField(TEXT("reliability"));
        Node.InitialState = ParseDiscoveryState(Object->GetStringField(TEXT("initial_state")));
        Node.bInitialVisible = InitiallyVisible.Contains(Node.EntryId);
        ReadNameArray(Object, TEXT("related_entry_ids"), Node.RelatedEntryIds);
        ReadNameArray(Object, TEXT("contradiction_entry_ids"), Node.ContradictionEntryIds);
        ReadNameArray(Object, TEXT("source_ids"), Node.SourceIds);

        NodeIndexById.Add(Node.EntryId, Nodes.Num());
        Nodes.Add(MoveTemp(Node));
    }

    if (Root->HasField(TEXT("reconstructions")))
    {
        for (const TSharedPtr<FJsonValue>& Value : Root->GetArrayField(TEXT("reconstructions")))
        {
            const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
            if (!Object.IsValid())
            {
                continue;
            }

            FLITD2ArchiveVisualReconstruction Reconstruction;
            Reconstruction.ReconstructionId = FName(*Object->GetStringField(TEXT("reconstruction_id")));
            Reconstruction.Title = FText::FromString(Object->GetStringField(TEXT("title")));
            Reconstruction.ResultEntryId = FName(*Object->GetStringField(TEXT("result_entry_id")));
            ReadNameArray(Object, TEXT("required_entry_ids"), Reconstruction.RequiredEntryIds);

            if (Object->HasField(TEXT("alternative_requirement_groups")))
            {
                for (const TSharedPtr<FJsonValue>& GroupValue : Object->GetArrayField(TEXT("alternative_requirement_groups")))
                {
                    const TSharedPtr<FJsonObject> GroupObject = GroupValue.IsValid() ? GroupValue->AsObject() : nullptr;
                    if (!GroupObject.IsValid())
                    {
                        continue;
                    }
                    FLITD2KnowledgeRequirementGroup Group;
                    Group.MinimumMatches = GroupObject->GetIntegerField(TEXT("minimum_matches"));
                    ReadNameArray(GroupObject, TEXT("any_of_entry_ids"), Group.AnyOfEntryIds);
                    ReadNameArray(GroupObject, TEXT("any_of_source_ids"), Group.AnyOfSourceIds);
                    Reconstruction.AlternativeRequirementGroups.Add(MoveTemp(Group));
                }
            }

            if (Object->HasField(TEXT("unlocks")))
            {
                for (const TSharedPtr<FJsonValue>& UnlockValue : Object->GetArrayField(TEXT("unlocks")))
                {
                    const TSharedPtr<FJsonObject> UnlockObject = UnlockValue.IsValid() ? UnlockValue->AsObject() : nullptr;
                    if (!UnlockObject.IsValid())
                    {
                        continue;
                    }
                    FLITD2GameplayUnlock Unlock;
                    Unlock.UnlockId = FName(*UnlockObject->GetStringField(TEXT("unlock_id")));
                    Unlock.Type = ParseUnlockType(UnlockObject->GetStringField(TEXT("type")));
                    Unlock.IntegerValue = UnlockObject->GetIntegerField(TEXT("integer_value"));
                    Unlock.Explanation = FText::FromString(UnlockObject->GetStringField(TEXT("explanation")));
                    Reconstruction.Unlocks.Add(MoveTemp(Unlock));
                }
            }

            Reconstructions.Add(MoveTemp(Reconstruction));
        }
    }

    return Nodes.Num() > 0;
}

bool ULITD2RemembranceArchiveScreen::LoadLayoutJson(const FString& AbsolutePath)
{
    FString JsonText;
    if (!FFileHelper::LoadFileToString(JsonText, *AbsolutePath))
    {
        return false;
    }

    TSharedPtr<FJsonObject> Root;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonText);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid() || !Root->HasField(TEXT("nodes")))
    {
        return false;
    }

    TSet<FName> LaidOutIds;
    for (const TSharedPtr<FJsonValue>& Value : Root->GetArrayField(TEXT("nodes")))
    {
        const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
        if (!Object.IsValid())
        {
            continue;
        }

        const FName EntryId(*Object->GetStringField(TEXT("entry_id")));
        if (const int32* Index = NodeIndexById.Find(EntryId))
        {
            Nodes[*Index].NormalizedPosition = FVector2D(
                FMath::Clamp(Object->GetNumberField(TEXT("x")), 0.04, 0.96),
                FMath::Clamp(Object->GetNumberField(TEXT("y")), 0.06, 0.94));
            LaidOutIds.Add(EntryId);
        }
    }

    return LaidOutIds.Num() == Nodes.Num();
}

void ULITD2RemembranceArchiveScreen::BuildFallbackLayout()
{
    const int32 Count = FMath::Max(1, Nodes.Num());
    for (int32 Index = 0; Index < Nodes.Num(); ++Index)
    {
        const double Angle = (2.0 * PI * Index / Count) - (PI * 0.5);
        const double Radius = 0.28 + (Index % 3) * 0.045;
        Nodes[Index].NormalizedPosition = FVector2D(
            0.5 + FMath::Cos(Angle) * Radius,
            0.5 + FMath::Sin(Angle) * Radius);
    }
}

void ULITD2RemembranceArchiveScreen::InitializeAuthoringDefaults()
{
    if (!RemembranceSubsystem)
    {
        return;
    }

    for (const FLITD2ArchiveVisualNode& Node : Nodes)
    {
        if (Node.bInitialVisible && Node.InitialState != ELITD2RemembranceDiscoveryState::Unknown &&
            RemembranceSubsystem->GetEntryState(Node.EntryId) == ELITD2RemembranceDiscoveryState::Unknown)
        {
            RemembranceSubsystem->SetEntryState(Node.EntryId, Node.InitialState);
        }
    }
}

ELITD2RemembranceDiscoveryState ULITD2RemembranceArchiveScreen::GetNodeState(const FLITD2ArchiveVisualNode& Node) const
{
    if (RemembranceSubsystem)
    {
        const ELITD2RemembranceDiscoveryState RuntimeState = RemembranceSubsystem->GetEntryState(Node.EntryId);
        if (RuntimeState != ELITD2RemembranceDiscoveryState::Unknown)
        {
            return RuntimeState;
        }
    }
    return Node.InitialState;
}

bool ULITD2RemembranceArchiveScreen::IsNodeVisible(const FLITD2ArchiveVisualNode& Node) const
{
    return Node.bInitialVisible || GetNodeState(Node) != ELITD2RemembranceDiscoveryState::Unknown;
}

FVector2D ULITD2RemembranceArchiveScreen::GetNodeLocalPosition(
    const FLITD2ArchiveVisualNode& Node,
    const FVector2D& LocalSize) const
{
    const double GraphWidth = LocalSize.X * GraphWidthRatio;
    const FVector2D GraphSize(GraphWidth, LocalSize.Y);
    const FVector2D Center = GraphSize * 0.5;
    const FVector2D Base(Node.NormalizedPosition.X * GraphSize.X, Node.NormalizedPosition.Y * GraphSize.Y);
    return Center + (Base - Center) * Zoom + PanOffset;
}

int32 ULITD2RemembranceArchiveScreen::HitTestNode(const FGeometry& Geometry, const FVector2D& LocalPosition) const
{
    const FVector2D LocalSize = Geometry.GetLocalSize();
    const FVector2D HalfSize(78.0, 30.0);
    for (int32 Index = Nodes.Num() - 1; Index >= 0; --Index)
    {
        const FLITD2ArchiveVisualNode& Node = Nodes[Index];
        if (!IsNodeVisible(Node))
        {
            continue;
        }

        const FVector2D Center = GetNodeLocalPosition(Node, LocalSize);
        if (FMath::Abs(LocalPosition.X - Center.X) <= HalfSize.X &&
            FMath::Abs(LocalPosition.Y - Center.Y) <= HalfSize.Y)
        {
            return Index;
        }
    }
    return INDEX_NONE;
}

void ULITD2RemembranceArchiveScreen::SelectEntry(FName EntryId)
{
    if (NodeIndexById.Contains(EntryId))
    {
        SelectedEntryId = EntryId;
        InvalidateLayoutAndVolatility();
    }
}

int32 ULITD2RemembranceArchiveScreen::FindAvailableReconstruction() const
{
    if (!RemembranceSubsystem)
    {
        return INDEX_NONE;
    }

    for (int32 Index = 0; Index < Reconstructions.Num(); ++Index)
    {
        const FLITD2ArchiveVisualReconstruction& Reconstruction = Reconstructions[Index];
        if (RemembranceSubsystem->IsReconstructionCompleted(Reconstruction.ReconstructionId))
        {
            continue;
        }

        bool bReady = true;
        for (const FName EntryId : Reconstruction.RequiredEntryIds)
        {
            if (RemembranceSubsystem->GetEntryState(EntryId) == ELITD2RemembranceDiscoveryState::Unknown)
            {
                bReady = false;
                break;
            }
        }
        if (!bReady)
        {
            continue;
        }

        for (const FLITD2KnowledgeRequirementGroup& Group : Reconstruction.AlternativeRequirementGroups)
        {
            int32 Matches = 0;
            for (const FName EntryId : Group.AnyOfEntryIds)
            {
                Matches += RemembranceSubsystem->GetEntryState(EntryId) != ELITD2RemembranceDiscoveryState::Unknown ? 1 : 0;
            }
            for (const FName SourceId : Group.AnyOfSourceIds)
            {
                Matches += RemembranceSubsystem->HasDiscoveredSource(SourceId) ? 1 : 0;
            }
            if (Matches < FMath::Max(1, Group.MinimumMatches))
            {
                bReady = false;
                break;
            }
        }

        if (bReady)
        {
            return Index;
        }
    }

    return INDEX_NONE;
}

bool ULITD2RemembranceArchiveScreen::TryReconstructAvailable()
{
    const int32 Index = FindAvailableReconstruction();
    if (Index == INDEX_NONE || !RemembranceSubsystem)
    {
        return false;
    }

    const FLITD2ArchiveVisualReconstruction& Definition = Reconstructions[Index];
    ULITD2RemembranceReconstruction* RuntimeDefinition = NewObject<ULITD2RemembranceReconstruction>(this);
    RuntimeDefinition->ReconstructionId = Definition.ReconstructionId;
    RuntimeDefinition->Title = Definition.Title;
    RuntimeDefinition->RequiredEntryIds = Definition.RequiredEntryIds;
    RuntimeDefinition->AlternativeRequirementGroups = Definition.AlternativeRequirementGroups;
    RuntimeDefinition->ResultEntryId = Definition.ResultEntryId;
    RuntimeDefinition->Unlocks = Definition.Unlocks;

    if (!RemembranceSubsystem->ApplyReconstruction(RuntimeDefinition))
    {
        return false;
    }

    RemembranceSubsystem->SaveArchives();
    SelectedEntryId = Definition.ResultEntryId;
    ReconstructionPulseEntryId = Definition.ResultEntryId;
    ReconstructionPulseSeconds = 1.1f;
    InvalidateLayoutAndVolatility();
    return true;
}

void ULITD2RemembranceArchiveScreen::NativeTick(const FGeometry& MyGeometry, float InDeltaTime)
{
    Super::NativeTick(MyGeometry, InDeltaTime);
    if (ReconstructionPulseSeconds > 0.0f)
    {
        ReconstructionPulseSeconds = FMath::Max(0.0f, ReconstructionPulseSeconds - InDeltaTime);
        InvalidateLayoutAndVolatility();
    }
}

FLinearColor ULITD2RemembranceArchiveScreen::CategoryColor(const FString& Category) const
{
    if (Category == TEXT("Body")) return FLinearColor(0.50f, 0.09f, 0.08f, 1.0f);
    if (Category == TEXT("Mind")) return FLinearColor(0.82f, 0.82f, 0.75f, 1.0f);
    if (Category == TEXT("Politics")) return FLinearColor(0.64f, 0.47f, 0.19f, 1.0f);
    if (Category == TEXT("Medicine")) return FLinearColor(0.82f, 0.69f, 0.63f, 1.0f);
    if (Category == TEXT("Technology")) return FLinearColor(0.52f, 0.57f, 0.61f, 1.0f);
    if (Category == TEXT("Person")) return FLinearColor(0.76f, 0.60f, 0.38f, 1.0f);
    if (Category == TEXT("Faction")) return FLinearColor(0.52f, 0.38f, 0.20f, 1.0f);
    if (Category == TEXT("Place") || Category == TEXT("City")) return FLinearColor(0.42f, 0.36f, 0.27f, 1.0f);
    return FLinearColor(0.25f, 0.23f, 0.22f, 1.0f);
}

FString ULITD2RemembranceArchiveScreen::DisplayState(ELITD2RemembranceDiscoveryState State) const
{
    switch (State)
    {
        case ELITD2RemembranceDiscoveryState::Trace: return TEXT("TRACE");
        case ELITD2RemembranceDiscoveryState::Documented: return TEXT("DOCUMENTÉ");
        case ELITD2RemembranceDiscoveryState::Reconstructed: return TEXT("RECONSTRUIT");
        case ELITD2RemembranceDiscoveryState::Contested: return TEXT("CONTESTÉ");
        default: return TEXT("INCONNU");
    }
}

FString ULITD2RemembranceArchiveScreen::ReliabilityLabel(const FString& Reliability) const
{
    if (Reliability == TEXT("Confirmed")) return TEXT("Confirmé");
    if (Reliability == TEXT("Probable")) return TEXT("Probable");
    if (Reliability == TEXT("Contested")) return TEXT("Contesté");
    if (Reliability == TEXT("SingleTestimony")) return TEXT("Témoignage unique");
    if (Reliability == TEXT("ProbablePropaganda")) return TEXT("Propagande probable");
    return TEXT("Incertain");
}

int32 ULITD2RemembranceArchiveScreen::NativePaint(
    const FPaintArgs& Args,
    const FGeometry& AllottedGeometry,
    const FSlateRect& MyCullingRect,
    FSlateWindowElementList& OutDrawElements,
    int32 LayerId,
    const FWidgetStyle& InWidgetStyle,
    bool bParentEnabled) const
{
    const int32 SuperLayer = Super::NativePaint(
        Args,
        AllottedGeometry,
        MyCullingRect,
        OutDrawElements,
        LayerId,
        InWidgetStyle,
        bParentEnabled);

    int32 Layer = FMath::Max(LayerId, SuperLayer) + 1;
    const FVector2D Size = AllottedGeometry.GetLocalSize();
    const double GraphWidth = Size.X * GraphWidthRatio;
    const double PanelX = GraphWidth + 10.0;
    const double PanelWidth = FMath::Max(220.0, Size.X - PanelX - 12.0);

    DrawSolidBox(OutDrawElements, Layer, AllottedGeometry, FVector2D::ZeroVector, Size, FLinearColor(0.008f, 0.009f, 0.012f, 0.98f));
    DrawSolidBox(OutDrawElements, Layer + 1, AllottedGeometry, FVector2D(0.0, 0.0), FVector2D(GraphWidth, Size.Y), FLinearColor(0.025f, 0.020f, 0.021f, 0.96f));
    DrawSolidBox(OutDrawElements, Layer + 1, AllottedGeometry, FVector2D(PanelX, 10.0), FVector2D(PanelWidth, Size.Y - 20.0), FLinearColor(0.035f, 0.025f, 0.027f, 0.98f));

    DrawTextLine(OutDrawElements, Layer + 3, AllottedGeometry, FVector2D(28.0, 20.0), TEXT("ARCHIVES DE RÉMANENCE"), 22, FLinearColor(0.72f, 0.57f, 0.28f), true);
    DrawTextLine(OutDrawElements, Layer + 3, AllottedGeometry, FVector2D(28.0, 49.0), TEXT("Certaines traces peuvent être reliées."), 11, FLinearColor(0.64f, 0.61f, 0.56f));

    // Relationship layer: muted solid threads and broken contradiction threads.
    for (const FLITD2ArchiveVisualNode& Node : Nodes)
    {
        if (!IsNodeVisible(Node))
        {
            continue;
        }
        const FVector2D Start = GetNodeLocalPosition(Node, Size);

        for (const FName RelatedId : Node.RelatedEntryIds)
        {
            const int32* RelatedIndex = NodeIndexById.Find(RelatedId);
            if (!RelatedIndex || !IsNodeVisible(Nodes[*RelatedIndex]) || Node.EntryId.ToString() >= RelatedId.ToString())
            {
                continue;
            }
            DrawLine(
                OutDrawElements,
                Layer + 2,
                AllottedGeometry,
                Start,
                GetNodeLocalPosition(Nodes[*RelatedIndex], Size),
                FLinearColor(0.45f, 0.36f, 0.23f, 0.34f),
                1.2f);
        }

        for (const FName ContradictionId : Node.ContradictionEntryIds)
        {
            const int32* OtherIndex = NodeIndexById.Find(ContradictionId);
            if (!OtherIndex || !IsNodeVisible(Nodes[*OtherIndex]) || Node.EntryId.ToString() >= ContradictionId.ToString())
            {
                continue;
            }
            DrawDashedLine(
                OutDrawElements,
                Layer + 2,
                AllottedGeometry,
                Start,
                GetNodeLocalPosition(Nodes[*OtherIndex], Size),
                FLinearColor(0.62f, 0.12f, 0.10f, 0.88f),
                2.0f);
        }
    }

    const FVector2D NodeSize(156.0, 60.0);
    for (const FLITD2ArchiveVisualNode& Node : Nodes)
    {
        if (!IsNodeVisible(Node))
        {
            continue;
        }

        const ELITD2RemembranceDiscoveryState State = GetNodeState(Node);
        const FVector2D Center = GetNodeLocalPosition(Node, Size);
        const FVector2D TopLeft = Center - NodeSize * 0.5;
        const FLinearColor Accent = CategoryColor(Node.Category);
        const bool bSelected = Node.EntryId == SelectedEntryId;
        const bool bUnknown = State == ELITD2RemembranceDiscoveryState::Unknown;

        if (bSelected)
        {
            DrawSolidBox(OutDrawElements, Layer + 4, AllottedGeometry, TopLeft - FVector2D(3.0, 3.0), NodeSize + FVector2D(6.0, 6.0), FLinearColor(0.76f, 0.57f, 0.25f, 0.90f));
        }
        else
        {
            DrawSolidBox(OutDrawElements, Layer + 4, AllottedGeometry, TopLeft - FVector2D(2.0, 2.0), NodeSize + FVector2D(4.0, 4.0), Accent.CopyWithNewOpacity(0.82f));
        }

        DrawSolidBox(OutDrawElements, Layer + 5, AllottedGeometry, TopLeft, NodeSize, bUnknown ? FLinearColor(0.018f, 0.018f, 0.021f, 0.98f) : FLinearColor(0.055f, 0.043f, 0.043f, 0.98f));
        DrawTextLine(OutDrawElements, Layer + 6, AllottedGeometry, TopLeft + FVector2D(10.0, 9.0), bUnknown ? TEXT("????????") : Node.Title.ToString(), 12, bUnknown ? FLinearColor(0.50f, 0.48f, 0.45f) : FLinearColor(0.90f, 0.85f, 0.76f), true);
        DrawTextLine(OutDrawElements, Layer + 6, AllottedGeometry, TopLeft + FVector2D(10.0, 35.0), DisplayState(State), 9, Accent);

        if (ReconstructionPulseSeconds > 0.0f && Node.EntryId == ReconstructionPulseEntryId)
        {
            const float Alpha = FMath::Clamp(ReconstructionPulseSeconds / 1.1f, 0.0f, 1.0f);
            const double Expansion = (1.0 - Alpha) * 34.0;
            DrawSolidBox(
                OutDrawElements,
                Layer + 7,
                AllottedGeometry,
                TopLeft - FVector2D(Expansion, Expansion),
                NodeSize + FVector2D(Expansion * 2.0, Expansion * 2.0),
                FLinearColor(0.83f, 0.66f, 0.30f, Alpha * 0.30f));
        }
    }

    // Dossier side panel.
    DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, 30.0), TEXT("DOSSIER"), 15, FLinearColor(0.70f, 0.53f, 0.25f), true);
    double PanelY = 65.0;

    const FLITD2ArchiveVisualNode* SelectedNode = nullptr;
    if (const int32* SelectedIndex = NodeIndexById.Find(SelectedEntryId))
    {
        SelectedNode = &Nodes[*SelectedIndex];
    }

    if (SelectedNode)
    {
        const ELITD2RemembranceDiscoveryState State = GetNodeState(*SelectedNode);
        const bool bUnknown = State == ELITD2RemembranceDiscoveryState::Unknown;
        DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), bUnknown ? TEXT("????????") : SelectedNode->Title.ToString(), 18, FLinearColor(0.91f, 0.84f, 0.72f), true);
        PanelY += 31.0;
        DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), SelectedNode->Category.ToUpper() + TEXT("  •  ") + DisplayState(State), 10, CategoryColor(SelectedNode->Category));
        PanelY += 24.0;
        DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), TEXT("Fiabilité : ") + ReliabilityLabel(SelectedNode->Reliability), 10, FLinearColor(0.64f, 0.61f, 0.56f));
        PanelY += 35.0;

        if (!bUnknown)
        {
            const int32 MaxChars = FMath::Clamp(static_cast<int32>(PanelWidth / 7.2), 28, 58);
            TArray<FString> DescriptionLines = WrapWords(SelectedNode->Description.ToString(), MaxChars);
            if (DescriptionLines.Num() > 10)
            {
                DescriptionLines.SetNum(10);
                DescriptionLines.Last() += TEXT("…");
            }
            for (const FString& DescriptionLine : DescriptionLines)
            {
                DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), DescriptionLine, 11, FLinearColor(0.80f, 0.77f, 0.70f));
                PanelY += 18.0;
            }

            PanelY += 20.0;
            DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), FString::Printf(TEXT("Sources connues : %d"), SelectedNode->SourceIds.Num()), 10, FLinearColor(0.58f, 0.55f, 0.50f));
            PanelY += 19.0;
            DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), FString::Printf(TEXT("Connexions : %d"), SelectedNode->RelatedEntryIds.Num()), 10, FLinearColor(0.58f, 0.55f, 0.50f));
            PanelY += 19.0;

            if (SelectedNode->ContradictionEntryIds.Num() > 0)
            {
                DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), TEXT("CONTRADICTION DÉTECTÉE"), 10, FLinearColor(0.74f, 0.18f, 0.14f), true);
            }
        }
        else
        {
            DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), TEXT("La relation existe, mais son sens reste inconnu."), 11, FLinearColor(0.55f, 0.52f, 0.48f));
        }
    }
    else
    {
        DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(PanelX + 24.0, PanelY), TEXT("Sélectionnez une trace."), 12, FLinearColor(0.64f, 0.61f, 0.56f));
    }

    const int32 AvailableReconstruction = FindAvailableReconstruction();
    if (AvailableReconstruction != INDEX_NONE)
    {
        const FVector2D ButtonPosition(PanelX + 22.0, Size.Y - 84.0);
        const FVector2D ButtonSize(PanelWidth - 44.0, 48.0);
        DrawSolidBox(OutDrawElements, Layer + 4, AllottedGeometry, ButtonPosition, ButtonSize, FLinearColor(0.42f, 0.25f, 0.08f, 0.98f));
        DrawTextLine(OutDrawElements, Layer + 5, AllottedGeometry, ButtonPosition + FVector2D(15.0, 14.0), TEXT("RECONSTRUIRE — ") + Reconstructions[AvailableReconstruction].Title.ToString(), 10, FLinearColor(0.95f, 0.84f, 0.58f), true);
    }

    DrawTextLine(OutDrawElements, Layer + 4, AllottedGeometry, FVector2D(28.0, Size.Y - 30.0), TEXT("Clic : inspecter   •   glisser : déplacer   •   molette : zoom"), 9, FLinearColor(0.49f, 0.46f, 0.42f));

    return Layer + 8;
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseButtonDown(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    if (InMouseEvent.GetEffectingButton() != EKeys::LeftMouseButton)
    {
        return Super::NativeOnMouseButtonDown(InGeometry, InMouseEvent);
    }

    const FVector2D LocalPosition = InGeometry.AbsoluteToLocal(InMouseEvent.GetScreenSpacePosition());
    const FVector2D Size = InGeometry.GetLocalSize();
    const double GraphWidth = Size.X * GraphWidthRatio;
    const double PanelX = GraphWidth + 10.0;
    const double PanelWidth = FMath::Max(220.0, Size.X - PanelX - 12.0);

    const int32 AvailableReconstruction = FindAvailableReconstruction();
    if (AvailableReconstruction != INDEX_NONE)
    {
        const FVector2D ButtonPosition(PanelX + 22.0, Size.Y - 84.0);
        const FVector2D ButtonSize(PanelWidth - 44.0, 48.0);
        if (LocalPosition.X >= ButtonPosition.X && LocalPosition.X <= ButtonPosition.X + ButtonSize.X &&
            LocalPosition.Y >= ButtonPosition.Y && LocalPosition.Y <= ButtonPosition.Y + ButtonSize.Y)
        {
            TryReconstructAvailable();
            return FReply::Handled();
        }
    }

    if (LocalPosition.X <= GraphWidth)
    {
        const int32 HitIndex = HitTestNode(InGeometry, LocalPosition);
        if (HitIndex != INDEX_NONE)
        {
            SelectedEntryId = Nodes[HitIndex].EntryId;
            InvalidateLayoutAndVolatility();
            return FReply::Handled();
        }

        bDraggingGraph = true;
        LastDragLocal = LocalPosition;
        return FReply::Handled().CaptureMouse(TakeWidget());
    }

    return FReply::Unhandled();
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseButtonUp(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    if (InMouseEvent.GetEffectingButton() == EKeys::LeftMouseButton && bDraggingGraph)
    {
        bDraggingGraph = false;
        return FReply::Handled().ReleaseMouseCapture();
    }
    return Super::NativeOnMouseButtonUp(InGeometry, InMouseEvent);
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseMove(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    if (!bDraggingGraph)
    {
        return Super::NativeOnMouseMove(InGeometry, InMouseEvent);
    }

    const FVector2D LocalPosition = InGeometry.AbsoluteToLocal(InMouseEvent.GetScreenSpacePosition());
    PanOffset += LocalPosition - LastDragLocal;
    LastDragLocal = LocalPosition;
    InvalidateLayoutAndVolatility();
    return FReply::Handled();
}

FReply ULITD2RemembranceArchiveScreen::NativeOnMouseWheel(
    const FGeometry& InGeometry,
    const FPointerEvent& InMouseEvent)
{
    const FVector2D LocalPosition = InGeometry.AbsoluteToLocal(InMouseEvent.GetScreenSpacePosition());
    const FVector2D Size = InGeometry.GetLocalSize();
    const double GraphWidth = Size.X * GraphWidthRatio;
    if (LocalPosition.X > GraphWidth)
    {
        return Super::NativeOnMouseWheel(InGeometry, InMouseEvent);
    }

    const float PreviousZoom = Zoom;
    Zoom = FMath::Clamp(Zoom * FMath::Pow(1.14f, InMouseEvent.GetWheelDelta()), MinZoom, MaxZoom);
    if (!FMath::IsNearlyEqual(PreviousZoom, Zoom))
    {
        const FVector2D Center(GraphWidth * 0.5, Size.Y * 0.5);
        const FVector2D GraphPointBeforeZoom = (LocalPosition - Center - PanOffset) / PreviousZoom;
        PanOffset = LocalPosition - Center - GraphPointBeforeZoom * Zoom;
        InvalidateLayoutAndVolatility();
    }

    return FReply::Handled();
}
