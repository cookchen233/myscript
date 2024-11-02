<?php

namespace app\common\bean;

/**
 * 表描述: {{table_comment}}<br/>
 * 表名: {{table_name}}
 */
class {{bean_name}} extends BasicBean
{
    {% for property in properties %}
    /**
     * {{property.field_comment}}
     */
    private ${{property.name}};
    {% endfor %}{% for property in properties %}
    /**
     * 获取 {{property.field_comment}}
     * @return {{property.property_type}}|null {{property.field_comment}}
     */
    public function {{property.get_method_name}}() : ?{{property.property_type}}
    {
        return $this->{{property.name}};
    }

    /**
     * 设置 {{property.field_comment}}
     * @param {{property.property_type}}|null ${{property.name}} {{property.field_comment}}
     * @return {{bean_name}} 当前对象
     */
    public function {{property.set_method_name}}({{property.property_type}} ${{property.name}} = null) : {{bean_name}}
    {
        $this->{{property.name}} = ${{property.name}};
        $this->flagSet('{{property.name}}');
        return $this;
    }
    {% endfor %}
    /**
     * 构造函数<br/><br/>
     * 表描述: {{table_comment}}<br/>
     * 表名: {{table_name}}
     * @param array $row 一条数据
     */
    public function __construct($row = [])
    {   {% for property in properties %}
        $this->{{property.name}} = isset($row['{{property.field_name}}']) ? $row['{{property.field_name}}'] : $this->{{property.name}};{% endfor %}
    }

    /**
     * 附加上类的信息（注意在定义函数时需要指定对应的返回值的类型）
     * @param mixed $object 对象
     * @return {{bean_name}}|null
     */
    public static function attachClassInfo($object) : ?{{bean_name}}
    {
        return $object;
    }

    /**
     * 转成字符串
     * @return string|null 字符串
     */
    public function __toString() : ?string
    {
        return dump($this, false);
    }

    /**
     * 转成数组
     * @param bool $includeAllFields 是否包含全部字段(true - 包含全部字段, false(默认) - 只包含调用过对应的setter方法的字段)
     * @return array 数组
     */
    public function toArray(bool $includeAllFields = false) : array
    {
        $data = array();
        {% for property in properties %}
        if ($includeAllFields === true || $this->isset('{{property.name}}')) {
            $data['{{property.field_name}}'] = $this->{{property.get_method_name}}();
        }
        {% endfor %}
        return $data;
    }
}
