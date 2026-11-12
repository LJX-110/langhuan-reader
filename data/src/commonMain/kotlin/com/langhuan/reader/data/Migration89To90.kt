package com.langhuan.reader.data

import androidx.room3.DeleteTable
import androidx.room3.migration.AutoMigrationSpec

/**
 * 89→90 自动迁移: 删除已废弃的书源过滤规则表。
 *
 * 书源过滤规则功能整条移除 (实体/DAO/搜索与发现过滤/导入导出全删), 旧规则数据不再保留;
 * Room 从新旧 schema 对比中发现该表被丢弃, 需用 @DeleteTable 显式声明删除动作。
 * 纯表结构变化, 无数据清洗, 故不重写 onPostMigrate。
 */
@DeleteTable.Entries(
    DeleteTable(tableName = "source_filter_rules"),
)
class Migration89To90 : AutoMigrationSpec
