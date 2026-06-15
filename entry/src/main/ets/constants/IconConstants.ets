/**
 * IconConstants — 图标资源映射。
 *
 * 所有图标来自 HarmonyOS_Icons 目录。
 * 以此为单点入口，组件通过语义名称引用图标，不直接硬编码 UUID。
 *
 * 使用方式:
 *   Image(IconConstants.IC_SEARCH).width(20).height(20)
 *   或
 *   Image($r('app.media.ic_search')).width(20).height(20)
 *
 * 对应文件: entry/src/main/resources/base/media/ic_*.svg
 */

/** 图标语义名称常量 */
export class IconConstants {
  // 导航/操作
  static readonly IC_SEARCH: Resource = $r('app.media.ic_search')
  static readonly IC_CLOSE: Resource = $r('app.media.ic_close')
  static readonly IC_ADD: Resource = $r('app.media.ic_add')
  static readonly IC_MINUS: Resource = $r('app.media.ic_minus')
  static readonly IC_CHECK: Resource = $r('app.media.ic_check')

  // 文件/文件夹
  static readonly IC_FOLDER: Resource = $r('app.media.ic_folder')
  static readonly IC_FOLDER_NEW: Resource = $r('app.media.ic_folder_new')
  static readonly IC_NOTE: Resource = $r('app.media.ic_note')
  static readonly IC_EDIT: Resource = $r('app.media.ic_edit')
  static readonly IC_DELETE: Resource = $r('app.media.ic_delete')
  static readonly IC_SAVE: Resource = $r('app.media.ic_save')

  // 面板/视图
  static readonly IC_SIDEBAR: Resource = $r('app.media.ic_sidebar')
  static readonly IC_CHAT: Resource = $r('app.media.ic_chat')
  static readonly IC_SETTINGS: Resource = $r('app.media.ic_settings')
  static readonly IC_PREVIEW: Resource = $r('app.media.ic_preview')
  static readonly IC_PREVIEW_OFF: Resource = $r('app.media.ic_preview_off')
  static readonly IC_OUTLINE: Resource = $r('app.media.ic_outline')

  // 文本/格式
  static readonly IC_TEXT: Resource = $r('app.media.ic_text')
  static readonly IC_TEXT_PARAGRAPH: Resource = $r('app.media.ic_text_paragraph')
  static readonly IC_CODE: Resource = $r('app.media.ic_code')
  static readonly IC_LINK: Resource = $r('app.media.ic_link')
  static readonly IC_TABLE: Resource = $r('app.media.ic_table')

  // 媒体
  static readonly IC_IMAGE: Resource = $r('app.media.ic_image')
  static readonly IC_MIC: Resource = $r('app.media.ic_mic')
  static readonly IC_CAMERA: Resource = $r('app.media.ic_camera')

  // 其他
  static readonly IC_ARROW_RIGHT: Resource = $r('app.media.ic_arrow_right')
  static readonly IC_ARROW_DOWN: Resource = $r('app.media.ic_arrow_down')
  static readonly IC_SYNC: Resource = $r('app.media.ic_sync')
}

/**
 * UUID 映射表 — 从 HarmonyOS_Icons 源目录复制时使用。
 * 位置: /storage/Users/currentUser/Download/com.haitai.htbrowser/HarmonyOS_Icons/
 */
export const ICON_COPY_MAP: Record<string, string> = {
  'ic_search': '2b8f58c3-ed63-4530-98fe-6e346beb503f',
  'ic_close': '4558cc9f-5e3a-49b0-b929-a666f6ced9cb',
  'ic_add': '633e2525-ce1d-4d92-ac5e-6e49272a49ad',
  'ic_minus': 'a3d2c5c3-f49a-4cea-bb66-525c75af2bdc',
  'ic_check': '8bb41832-3746-4f53-9f4b-41c46ca6764b',
  'ic_folder': '2a6a5314-5d53-41fa-b620-03ab30f0b46e',
  'ic_folder_new': '03abca84-2321-43b5-9ab0-f17a5d8111a7',
  'ic_note': '9bef0ab8-632a-4cd1-9518-df5d604b3f00',
  'ic_edit': 'ad6d89f2-ba0b-497f-8340-b1e937d1eff7',
  'ic_delete': '340f78eb-5e5e-49c5-8be6-8657386f0b7d',
  'ic_save': '7d36156a-fd7c-4188-8984-564415d09744',
  'ic_sidebar': '7c1f2091-7102-4c82-8925-455055caf500',
  'ic_chat': '6d8303db-c516-42f1-8a83-fe67039238c8',
  'ic_settings': '65bae51e-6e6c-486a-9679-a4bc417ecba0',
  'ic_preview': '1db8f413-b6d1-4019-ac3c-1c24424a3d1d',
  'ic_preview_off': '69a88159-4dc9-42ba-9274-cbfd7a289d3b',
  'ic_outline': '4526b459-3200-4356-ae18-075ab95080c1',
  'ic_text': '1c5fcae1-bd90-4eb9-8f69-c498aed3727f',
  'ic_text_paragraph': '1d09d050-2a93-4b2b-9dd4-780c2537bf87',
  'ic_code': 'ae12b657-302c-4e82-819a-5e90a041a9eb',
  'ic_link': '128a1063-c928-425d-a401-285295d30ae8',
  'ic_table': '200c458b-9919-4a57-80bb-0286f609d0e8',
  'ic_image': '203c80aa-3994-42af-9405-25815f04abcc',
  'ic_mic': '30de5aaa-867a-4888-81e0-c003162aa61d',
  'ic_camera': '89ce2991-870e-4a5f-b6e5-877a9d0ce193',
  'ic_arrow_right': '992ca5d3-24ed-44ae-82ae-8f602ad256c1',
  'ic_arrow_down': 'a70a6dc3-d931-42d0-a827-1d8e0db3aad3',
  'ic_sync': '428e84d8-43c4-428a-9a99-af6149c7543c',
}
