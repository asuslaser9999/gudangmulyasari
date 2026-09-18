/// Tabel & RPC Gudang Mulyasari — prefix `gm_` di database yang sama dengan Ultimate POS.
class GmTables {
  GmTables._();

  static const permissions = 'gm_permissions';
  static const roles = 'gm_roles';
  static const rolePermissions = 'gm_role_permissions';
  static const profiles = 'gm_profiles';
  static const userLocationAccess = 'gm_user_location_access';
  static const userItemAccess = 'gm_user_item_access';
  static const locations = 'gm_locations';
  static const items = 'gm_items';
  static const stockBalances = 'gm_stock_balances';
  static const stockDocs = 'gm_stock_docs';
  static const stockDocLines = 'gm_stock_doc_lines';
  static const appSettings = 'gm_app_settings';

  static const resolveLoginEmail = 'gm_resolve_login_email';
  static const postStockDoc = 'gm_post_stock_doc';
  static const voidStockTransferLine = 'gm_void_stock_transfer_line';
  static const voidStockReceiptLine = 'gm_void_stock_receipt_line';
  static const adminCreateUser = 'gm_admin_create_user';
  static const adminUpdateUser = 'gm_admin_update_user';
}
