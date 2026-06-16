# Markdown 测试文档 — MXNote 功能验证

本文档用于测试 MXNote 的 Markdown 渲染能力和各种功能。

---

## 1. 标题层级测试

# 一级标题 H1
## 二级标题 H2
### 三级标题 H3
#### 四级标题 H4
##### 五级标题 H5
###### 六级标题 H6

## 2. 文本格式测试

这是普通段落文本。**这是粗体文本**。*这是斜体文本*。***这是粗斜体文本***。``这是行内代码``。

~~这是删除线文本~~。

## 3. 代码块测试

```typescript
// TypeScript 代码块
export class NoteFile {
  id: string = ''
  title: string = ''
  content: string = ''
  createdAt: number = 0
  modifiedAt: number = 0
}
```

```python
# Python 代码块
def hello_world():
    print("Hello, MXNote!")
    return True
```

## 4. 引用块测试

> 这是一段引用文本。
> 引用可以有多行。
>
> > 这是嵌套引用。

## 5. 列表测试

### 无序列表

- 项目一
- 项目二
  - 子项目 A
  - 子项目 B
- 项目三

### 有序列表

1. 第一步
2. 第二步
3. 第三步
   1. 子步骤 a
   2. 子步骤 b

## 6. 分割线测试

下面是一条分割线：

---

分割线上方内容。

## 7. 链接测试

[HarmonyOS 开发者文档](https://developer.huawei.com/consumer/cn/harmonyos/)

## 8. 综合场景 — 技术笔记

### MXNote 项目架构

MXNote 使用 **HarmonyOS ArkTS** 原生开发，架构分层如下：

1. **constants/** — 主题令牌和图标常量
2. **core/** — 核心逻辑（文件管理、Markdown 解析）
3. **model/** — 数据模型
4. **pages/** — UI 页面和组件
5. **services/** — 业务服务（导入/导出）

> "好的架构是宁静的，它不言自明。"

#### 关键代码路径

```typescript
// 文件保存流程
async saveFile(): Promise<void> {
  await m.saveFile(this.activeId, this.activeTitle, this.activeContent)
  this.renderPreview()  // 自动渲染预览
}
```

#### 功能清单

- [x] 文件 CRUD
- [x] 文件夹管理
- [x] Markdown 预览
- [x] 搜索（标题+内容）
- [x] 导出/导入
- [ ] AI 对话
- [ ] 笔记同步

---

## 9. 边界测试

### 长段落

这是一段很长的文本用于测试 MXNote 编辑器的长段落渲染能力。ArkTS 的 TextArea 组件在单行长文本场景下需要测试其性能表现和内存占用情况。鸿蒙系统提供了优秀的文本渲染引擎，能够高效处理各种文本布局需求。

### 特殊字符

价格: ¥99.00  温度: 37°C  分数: 1/2

## 10. 性能验证用内容

在搜索框中输入 **"鸿蒙"** 应能匹配到本文档中的相关内容。

在搜索框中输入 **"createFile"** 应能匹配到代码块中的函数名。

---

> MXNote — Build with HarmonyOS.

没问题，这里为你准备了针对**表格渲染**、**代码高亮**和**LaTeX公式**三个核心模块的深度压力测试用例。

这些用例专门设计用来“折磨”渲染引擎，暴露其在边界情况和复杂场景下的缺陷。

---

## 一、 表格渲染压力测试 (Table Stress Test)

这部分主要测试解析器对**对齐方式、嵌套元素、超长文本、特殊字符**的处理能力。

### 1. 极窄列与超长文本（测试换行与布局）
| 序号 | 极窄列 | 超长文本内容（测试自动换行与单词截断） | 操作 |
| :---: | :---: | :--- | :---: |
| 1 | A | ThisIsASuperLongWordThatShouldBreakOrEllipsisBasedOnCSSRulesAndItKeepsGoingAndGoing... | [编辑] |
| 2 | B | 这是一段没有任何空格的中文超长文本，用来测试中文排版引擎是否能够正确进行换行截断而不破坏表格布局。 | [保存] |

### 2. 表头缺失与空单元格（测试健壮性）
| | 正常表头 | |
| :--- | :--- | :--- |
| 行1-缺省左 | 行1-中间 | 行1-缺省右 |
| | 行2-中间（左边为空） | 行2-右 |
| 行3-左 | | 行3-右（中间为空） |

### 3. 表格内嵌套 Markdown 元素（测试优先级解析）
| 类型 | 示例 | 预期结果 |
| :--- | :--- | :--- |
| **列表** | 1. 第一项<br>2. 第二项<br>- 子项A<br>- 子项B | 序号和数字必须正确显示，不能变成普通文本。 |
| **引用** | > 引用行1<br>> 引用行2 | 两行都应该有引用样式，或者整体作为一个块引用。 |
| **代码** | `var x = 1;` 和 ```<div>``` | 行内代码背景色应生效，注意区分反引号。 |
| **链接** | https://google.com 和 <https://github.com> | 两个链接都应可点击。 |
| **图片** | !https://via.placeholder.com/50 | 图片应在单元格内缩放或不溢出。 |

### 4. 分隔线攻击（测试正则匹配）
| 陷阱 1 | 陷阱 2 | 陷阱 3 |
| :--- | :--- | :--- |
| `|---|---|` (代码中的表格语法) | \\| 转义竖线 | 文本中包含 \| 管道符 |
| --- | --- | --- |
| 正常数据 | 正常数据 | 正常数据 |

### 5. 多行文本与 HTML 混排
| 功能 | 描述 |
| :--- | :--- |
| 详情 | 第一行文本。<br>第二行（使用HTML br标签）。<br><br>空一行后。<br><ul><li>HTML 列表项 1</li><li>HTML 列表项 2</li></ul> |

---

## 二、 代码高亮压力测试 (Code Highlighting Stress Test)

这部分主要测试词法分析器对**复杂语法、特殊字符、行号、长行**的处理能力。

### 1. 正则表达式地狱（测试 JS 高亮崩溃风险）
```javascript
// 极其复杂的正则，容易导致高亮引擎卡死或出错
const regex = /^(?:(?<protocol>https?|ftp):\/\/)?(?:(?<domain>[^\/\?:]+))(?::(?<port>\d+))?(?<path>\/[^\?#]*)?(?:\?(?<query>[^#]*))?(?:#(?<fragment>.*))?$/;

// 包含大量转义字符
const str = "\\\\\\\"\\'\\\\\"";
```

### 2. 模板字符串嵌套（测试上下文切换）
```javascript
const html = `
  <div class="${isActive ? 'active' : 'inactive'}">
    <span>${user.name}</span>
    <script>
      // 注意：这里的 JS 注释不应该影响外部的模板字符串高亮
      console.log('Hello');
    </script>
  </div>
`;
```

### 3. 多语言混合（测试 Sub-language / Embedding）
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <style type="text/css">
    /* CSS 注释 */
    body { background: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="); }
  </style>
</head>
<body>
  <?php echo "PHP Tag"; ?>
  <script type="application/javascript">
    // JS Code
    function init() {
      fetch('/api')
        .then(res => res.json())
        .then(data => console.log(`Data: ${data}`));
    }
  </script>
</body>
</html>
```

### 4. 行号与长行滚动
```python
# 这是一行非常长的代码，用来测试当代码超出容器宽度时，水平滚动条是否正常工作，以及行号是否与代码对齐，不会错位。如果行号固定住了，那么滚动代码时行号应该始终可见。
def very_long_function_name_that_causes_horizontal_scroll_bar_to_appear_in_the_preview_window(parameter_one, parameter_two, parameter_three, parameter_four, parameter_five):
    pass

# 测试行号连续性
a = 1
b = 2
c = 3
d = 4
e = 5
f = 6
g = 7
h = 8
i = 9
j = 10
```

### 5. Shell 脚本的特殊符号
```bash
# 测试 $() vs `` 以及变量替换
OUTPUT=$(ls -l | grep ".md")
COUNT=`wc -l <<< "$OUTPUT"`
echo "Found $COUNT markdown files."

# 测试注释中的特殊字符
# URL: https://example.com/path?query=1&sort=desc#anchor
```

---

## 三、 LaTeX 公式压力测试 (LaTeX / MathJax / KaTeX)

这部分主要测试数学引擎对**矩阵、多行对齐、大型括号、宏定义**的支持。

### 1. 巨型矩阵（测试渲染性能与布局）
$$
\mathbf{X} = \begin{pmatrix}
x_{11} & x_{12} & x_{13} & x_{14} & x_{15} \\
x_{21} & x_{22} & x_{23} & x_{24} & x_{25} \\
x_{31} & x_{32} & x_{33} & x_{34} & x_{35} \\
x_{41} & x_{42} & x_{43} & x_{44} & x_{45} \\
x_{51} & x_{52} & x_{53} & x_{54} & x_{55}
\end{pmatrix}
\cdot
\begin{bmatrix}
y_1 \\ y_2 \\ y_3 \\ y_4 \\ y_5
\end{bmatrix}
$$

### 2. 多行对齐公式（测试 `align` 环境）
$$
\begin{align*}
  f(x) &= (x+a)(x+b) \\
       &= x^2 + (a+b)x + ab \\
       &= x^2 + 2\left(\frac{a+b}{2}\right)x + ab \\
       &= \left(x+\frac{a+b}{2}\right)^2 - \left(\frac{a+b}{2}\right)^2 + ab \\
       &= \left(x+\frac{a+b}{2}\right)^2 - \frac{(a-b)^2}{4}
\end{align*}
$$

### 3. 大型括号与分段函数（测试定界符大小）
$$
f(x) = \left\{
  \begin{array}{lr}
    x^2 + 1, & \text{if } x \ge 0 \\
    \frac{1}{x}, & \text{if } x < 0 \text{ and } x \neq -1 \\
    \int_{0}^{\infty} e^{-t^2} dt, & \text{otherwise}
  \end{array}
\right.
$$

### 4. 行内公式的极限情况（测试行高溢出）
这是一个包含 $\sum_{i=1}^{n} \frac{1}{i} = H_n \approx \ln n + \gamma$ 的行内公式，注意它是否把这一行的行高撑得过高，导致文字排版混乱。

另一个例子：$\sqrt{\frac{\left(\frac{a}{b}\right)}{\left(\frac{c}{d}\right)}}$

### 5. 化学公式与特殊符号（测试扩展包）
$$
\ce{2H2 + O2 ->[\Delta] 2H2O}
$$

$$
\require{AMScd}
\begin{CD}
    A @>a>> B \\
    @V b V V @VV c V \\
    C @>>d> D
\end{CD}
$$

### 6. 错误处理测试（测试容错性）
如果输入错误的 LaTeX 语法，编辑器不应崩溃，而应显示红色的错误提示框。
$$ \frac{1}{2 $$ (缺少右括号)
$$ \begin{cases} x \end{ } $$ (环境未关闭)

---

## 测试建议

1.  **内存泄漏**：将上面的长代码块和巨大矩阵反复复制粘贴几十次，观察预览窗口是否会变得卡顿或崩溃。
2.  **滚动同步**：在编辑长表格或长代码时，滚动编辑区，检查预览区的滚动位置映射是否准确。
3.  **复制粘贴**：从生成的预览中复制表格内容到 Excel，检查格式是否丢失；复制代码是否带上了行号（通常不应该带）。

需要我再为你补充关于**Mermaid 流程图**或**脚注/锚点跳转**的专项测试吗？