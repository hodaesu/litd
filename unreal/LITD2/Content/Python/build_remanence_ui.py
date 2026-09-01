"""Generate the first UMG asset for the LITD 2 Remanence Archives.

The native parent class renders and owns the complete first-pass screen.  The
Widget Blueprint created here is therefore intentionally thin: it gives artists
an editable UMG asset without duplicating archive logic in Blueprint.
"""

import unreal

ASSET_NAME = "WBP_RemembranceArchive"
PACKAGE_PATH = "/Game/UI/Remanence"
ASSET_PATH = f"{PACKAGE_PATH}/{ASSET_NAME}"
PARENT_CLASS_PATH = "/Script/LITD2.LITD2RemembranceArchiveScreen"


def _load_parent_class():
    parent_class = unreal.load_class(None, PARENT_CLASS_PATH)
    if parent_class is None:
        raise RuntimeError(
            "LITD2RemembranceArchiveScreen est introuvable. Compilez LITD2Editor avant de générer l'UMG."
        )
    return parent_class


def _create_widget_blueprint(parent_class):
    factory = unreal.WidgetBlueprintFactory()
    factory.set_editor_property("parent_class", parent_class)
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    widget_blueprint = asset_tools.create_asset(
        ASSET_NAME,
        PACKAGE_PATH,
        unreal.WidgetBlueprint,
        factory,
    )
    if widget_blueprint is None:
        raise RuntimeError(f"Impossible de créer {ASSET_PATH}")
    return widget_blueprint


def build():
    parent_class = _load_parent_class()

    if unreal.EditorAssetLibrary.does_asset_exist(ASSET_PATH):
        widget_blueprint = unreal.EditorAssetLibrary.load_asset(ASSET_PATH)
        unreal.log(f"LITD2 Remanence UI: {ASSET_PATH} existe déjà, conservation de l'asset.")
    else:
        widget_blueprint = _create_widget_blueprint(parent_class)
        unreal.log(f"LITD2 Remanence UI: création de {ASSET_PATH}.")

    if widget_blueprint is None:
        raise RuntimeError(f"Asset UMG inaccessible: {ASSET_PATH}")

    unreal.EditorAssetLibrary.set_metadata_tag(widget_blueprint, "LITD2System", "RemanenceArchive")
    unreal.EditorAssetLibrary.set_metadata_tag(widget_blueprint, "NativeParent", PARENT_CLASS_PATH)
    unreal.EditorAssetLibrary.save_loaded_asset(widget_blueprint, only_if_is_dirty=False)
    unreal.log("LITD2 Remanence UI: génération terminée.")
    return ASSET_PATH


if __name__ == "__main__":
    build()
