/*
 * This file is part of moss-container.
 *
 * Copyright © 2020-2022 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.container.slist;
import core.stdc.stdlib : calloc, free;

/**
 * The "Real" list
 */
package struct SListNode(T)
{
    alias DataType = T;
    DataType data = T.init;
    SListNode!(DataType)* next = null;
}

/**
 * Singly linked list
 */
public struct SList(T)
{
    alias DataType = T;
    alias NodeType = SListNode!DataType;

    /**
     * Prepend a list item which will become the list head
     */
    void prepend()(auto const ref T data)
    {
        void* ret = calloc(1, NodeType.sizeof);
        assert(ret !is null);
        NodeType* node = cast(NodeType*) ret;
        assert(node !is null);
        node.data = data;
        node.next = nodes;
        nodes = node;
        ++nodeCount;
    }

    /**
     * Free any allocated list nodes
     */
    ~this()
    {
        NodeType* node = nodes;
        while (node !is null)
        {
            auto nextNode = node.next;
            free(node);
            node = nextNode;
        }
    }

private:

    NodeType* nodes = null;
    uint nodeCount = 0;
}
