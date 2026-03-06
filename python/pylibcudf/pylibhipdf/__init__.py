# MIT License
#
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import sys as _sys


# generic
class _MirrorModule:

    def __init__(
        self, name, module, parent
    ):  # type: (_MirrorModule, str, _sys.ModuleType, (str|None)) -> None
        self.parent = parent  # type: _MirrorModule
        self.module = module  # type: _sys.ModuleType
        self.name = name  # type: str
        self.children = []  # type: list[_MirrorModule]

    @property
    def global_name(self):  # type: (_MirrorModule) -> str
        current = self
        result = [current.name]
        while current.parent is not None:
            current = current.parent
            result.append(current.name)
        return ".".join(reversed(result))

    def get_or_insert(
        self, name, module
    ):  # type: (_MirrorModule, str, _sys.ModuleType) -> _MirrorModule
        """Get child with the given name, create it if it doesn't exist."""
        assert module is not None
        for child in self.children:
            if child.name == name:
                return child
        new_child = _MirrorModule(name, module, parent=self)
        self.children.append(new_child)
        return new_child

    def walk(self):
        """Pre-order walk through self and descendants."""
        yield self
        for child in self.children:
            yield from child.walk()

    def register(self):
        """Add original module to registry and to parent's attributes under given name."""
        assert self.parent is not None
        _sys.modules[self.global_name] = self.module
        if not hasattr(self.parent.module, self.name):
            setattr(self.parent.module, self.name, self.module)

    def register_all_descendants(self):
        """Register descendants but not self."""
        for node in self.walk():
            if node != self:
                node.register()


# project-specific
def _variants(mod):
    "Project-specific package name variant generator."
    yield mod
    if "pylibcudf" in mod:
        yield mod.replace("pylibcudf", "pylibhipdf")
    if mod == "nvtext":
        yield "hiptext"
    if "cuda" in mod:
        yield mod.replace("cuda", "hip")


# generic
def _descend(
    current, global_module_name_parts, lvl
):  # type: (_MirrorModule, list[str], int) -> None
    if lvl >= len(global_module_name_parts):
        return
    for v in _variants(global_module_name_parts[lvl]):
        _descend(
            current.get_or_insert(
                name=v,
                module=_sys.modules[
                    ".".join(global_module_name_parts[: lvl + 1])
                ],
            ),
            global_module_name_parts,
            lvl + 1,
        )


# project-specific
import pylibcudf as _mirrored

__version__ = getattr(_mirrored, "__version__")

_root = _MirrorModule("pylibhipdf", _mirrored, None)
for _key in _sys.modules.keys():
    if _key.startswith("pylibcudf."):
        _descend(_root, _key.split("."), 1)
_root.register_all_descendants()

from pylibcudf import *

# generic
for _child in _root.children:
    globals()[_child.name] = _child.module

del _mirrored
del _descend
del _key
del _MirrorModule
del _root
del _child
del _sys
del _variants

__all__ = list(globals().keys())
