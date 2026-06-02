/*
 * Local type definitions matching the librime C API expected by Qiwo Swift code.
 * Uses standard C types to avoid version-specific librime header complexities.
 */

#ifndef QIWO_RIME_TYPES_H_
#define QIWO_RIME_TYPES_H_

#include <stdint.h>
#include <stddef.h>

typedef int Bool;
typedef uintptr_t RimeSessionId;

typedef struct rime_traits_t {
  int data_size;
  int shared_data_dir_sz;
  int user_data_dir_sz;
  int distribution_name_sz;
  int distribution_code_name_sz;
  int distribution_version_sz;
  int app_name_sz;
  const char* shared_data_dir;
  const char* user_data_dir;
  const char* distribution_name;
  const char* distribution_code_name;
  const char* distribution_version;
  const char* app_name;
  const char* modules;
  int min_log_level;
  const char* log_dir;
  const char* prebuilt_data_dir;
  const char* staging_dir;
} RimeTraits;

typedef struct {
  int data_size;
  int text_size;
  const char* text;
} RimeCommit;

typedef struct rime_candidate_t {
  int data_size;
  int text_size;
  const char* text;
  const char* comment;
} RimeCandidate;

typedef struct {
  int data_size;
  int page_size;
  int page_no;
  Bool is_last_page;
  int highlighted_candidate_index;
  int num_candidates;
  RimeCandidate* candidates;
  const char* select_keys;
} RimeMenu_stdbool;

typedef struct rime_context_stdbool_t {
  int data_size;
  RimeCommit commit;
  RimeMenu_stdbool menu;
  const char* select_labels;
  int composition_length;
  int composition_cursor_pos;
  const char* composition_preedit;
  const char* input;
  int caret_pos;
} RimeContext_stdbool;

typedef struct rime_status_stdbool_t {
  int data_size;
  const char* schema_id;
  const char* schema_name;
  Bool is_disabled;
  Bool is_composing;
  Bool is_ascii_mode;
  Bool is_full_shape;
  Bool is_simplified;
  Bool is_traditional;
} RimeStatus_stdbool;

typedef struct rime_config_t {
  int data_size;
  void* ptr;
} RimeConfig;

typedef struct rime_config_iterator_t {
  int data_size;
  void* list;
  void* map;
  int index;
  const char* key;
  const char* path;
} RimeConfigIterator;

typedef struct rime_schema_list_item_t {
  int data_size;
  const char* schema_id;
  const char* name;
  int reserved;
} RimeSchemaListItem;

typedef struct rime_schema_list_t {
  size_t size;
  RimeSchemaListItem* list;
} RimeSchemaList;

typedef struct rime_module_t {
  int data_size;
  int module_size;
  const char* module_name;
  void (*initialize)(void);
  void (*finalize)(void);
  void* (*create)(RimeConfig* config);
  void (*destroy)(void* instance);
  Bool (*process_key_event)(void* instance, int keycode, int mask);
  int (*get_candidates)(void* instance, RimeContext_stdbool* context);
  Bool (*get_commit)(void* instance, RimeCommit* commit);
  Bool (*delete_candidate)(void* instance, size_t index);
  int (*modifier_update)(void* instance, int keycode, int mask, Bool release);
} RimeModule;

typedef struct rime_api_stdbool_t {
  int data_size;
  void (*setup)(RimeTraits* traits);
  void (*set_notification_handler)(void (*)(void*, RimeSessionId, const char*, const char*), void*);
  void (*initialize)(RimeTraits* traits);
  void (*finalize)(void);
  Bool (*start_maintenance)(Bool full_check);
  Bool (*is_maintenance_mode)(void);
  void (*join_maintenance_thread)(void);
  void (*deployer_initialize)(RimeTraits* traits);
  Bool (*prebuild)(void);
  Bool (*deploy)(void);
  RimeSessionId (*create_session)(void);
  Bool (*find_session)(RimeSessionId session_id);
  Bool (*destroy_session)(RimeSessionId session_id);
  void (*cleanup_stale_sessions)(void);
  void (*cleanup_all_sessions)(void);
  Bool (*process_key)(RimeSessionId session_id, int keycode, int mask);
  Bool (*commit_composition)(RimeSessionId session_id);
  void (*clear_composition)(RimeSessionId session_id);
  Bool (*get_commit)(RimeSessionId session_id, RimeCommit* commit);
  Bool (*free_commit)(RimeCommit* commit);
  Bool (*get_context)(RimeSessionId session_id, RimeContext_stdbool* context);
  Bool (*free_context)(RimeContext_stdbool* ctx);
  Bool (*get_status)(RimeSessionId session_id, RimeStatus_stdbool* status);
  Bool (*free_status)(RimeStatus_stdbool* status);
  void (*set_option)(RimeSessionId session_id, const char* option, Bool value);
  Bool (*get_option)(RimeSessionId session_id, const char* option);
  void (*set_property)(RimeSessionId session_id, const char* prop, const char* value);
  Bool (*get_property)(RimeSessionId session_id, const char* prop, char* value, size_t buffer_size);
  Bool (*schema_list)(RimeSchemaList* output);
  Bool (*schema_open)(const char* schema_id, RimeConfig* config);
  Bool (*config_open)(const char* config_id, RimeConfig* config);
  Bool (*config_close)(RimeConfig* config);
  Bool (*config_get_bool)(RimeConfig* config, const char* key, Bool* value);
  Bool (*config_get_int)(RimeConfig* config, const char* key, int* value);
  Bool (*config_get_double)(RimeConfig* config, const char* key, double* value);
  Bool (*config_get_string)(RimeConfig* config, const char* key, const char** value);
  int (*config_get_list_size)(RimeConfig* config, const char* key);
  Bool (*config_begin_list)(RimeConfigIterator* iterator, RimeConfig* config, const char* key);
  Bool (*config_begin_map)(RimeConfigIterator* iterator, RimeConfig* config, const char* key);
  Bool (*config_next)(RimeConfigIterator* iterator);
  void (*config_end)(RimeConfigIterator* iterator);
  Bool (*simulate_key_sequence)(RimeSessionId session_id, const char* key_sequence);
  Bool (*register_module)(RimeModule* module);
  Bool (*find_module)(const char* module_name, RimeModule** module);
  void (*run_task)(const char* task_name);
  const char* (*get_shared_data_dir)(void);
  const char* (*get_user_data_dir)(void);
  const char* (*get_sync_dir)(void);
  const char* (*get_distribution_name)(void);
  const char* (*get_distribution_code_name)(void);
  const char* (*get_distribution_version)(void);
  const char* (*get_user_id)(void);
  Bool (*get_input)(RimeSessionId session_id, const char** input);
  int (*candidate_count)(RimeSessionId session_id);
  Bool (*select_candidate)(RimeSessionId session_id, int index);
  const char* (*get_version)(void);
  Bool (*set_caret_pos)(RimeSessionId session_id, size_t caret_pos);
  Bool (*select_candidate_on_current_page)(RimeSessionId session_id, size_t index);
  Bool (*delete_candidate_on_current_page)(RimeSessionId session_id, size_t index);
  Bool (*highlight_candidate)(RimeSessionId session_id, size_t index);
  Bool (*change_page)(RimeSessionId session_id, Bool next);
  Bool (*is_on_first_page)(RimeSessionId session_id);
} RimeApi_stdbool;

#endif
