package com.langhuan.reader.lib.dialogs

import java.io.Serializable

data class SelectItem<T : Serializable>(
    val title: String,
    val value: T
) : Serializable {

    override fun toString(): String {
        return title
    }

}
