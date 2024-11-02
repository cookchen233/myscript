<?php

namespace app\common\bean;

/**
 * 表描述: 设备运维管理人员表<br/>
 * 表名: tp_device_operations_management
 */
class DeviceOperationsManagementBean extends BasicBean
{
    
    /**
     * 
     */
    private $deviceId;
    
    /**
     * 
     */
    private $adminId;
    
    /**
     * 
     */
    private $status;
    
    /**
     * 
     */
    private $startTime;
    
    /**
     * 创建时间
     */
    private $createTime;
    
    /**
     * 
     */
    private $creator;
    
    /**
     * 
     */
    private $isDelete;
    
    /**
     * 更新时间
     */
    private $updateTime;
    
    /**
     * 更新者
     */
    private $updator;
    
    /**
     * 是否结算服务费(0: 否, 1: 是)
     */
    private $needServiceFee;
    
    /**
     * 停止时间
     */
    private $stopTime;
    
    /**
     * 获取 
     * @return string|null 
     */
    public function getDeviceId() : ?string
    {
        return $this->deviceId;
    }

    /**
     * 设置 
     * @param string|null $deviceId 
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setDeviceId(string $deviceId = null) : DeviceOperationsManagementBean
    {
        $this->deviceId = $deviceId;
        $this->flagSet('deviceId');
        return $this;
    }
    
    /**
     * 获取 
     * @return int|null 
     */
    public function getAdminId() : ?int
    {
        return $this->adminId;
    }

    /**
     * 设置 
     * @param int|null $adminId 
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setAdminId(int $adminId = null) : DeviceOperationsManagementBean
    {
        $this->adminId = $adminId;
        $this->flagSet('adminId');
        return $this;
    }
    
    /**
     * 获取 
     * @return int|null 
     */
    public function getStatus() : ?int
    {
        return $this->status;
    }

    /**
     * 设置 
     * @param int|null $status 
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setStatus(int $status = null) : DeviceOperationsManagementBean
    {
        $this->status = $status;
        $this->flagSet('status');
        return $this;
    }
    
    /**
     * 获取 
     * @return string|null 
     */
    public function getStartTime() : ?string
    {
        return $this->startTime;
    }

    /**
     * 设置 
     * @param string|null $startTime 
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setStartTime(string $startTime = null) : DeviceOperationsManagementBean
    {
        $this->startTime = $startTime;
        $this->flagSet('startTime');
        return $this;
    }
    
    /**
     * 获取 创建时间
     * @return string|null 创建时间
     */
    public function getCreateTime() : ?string
    {
        return $this->createTime;
    }

    /**
     * 设置 创建时间
     * @param string|null $createTime 创建时间
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setCreateTime(string $createTime = null) : DeviceOperationsManagementBean
    {
        $this->createTime = $createTime;
        $this->flagSet('createTime');
        return $this;
    }
    
    /**
     * 获取 
     * @return string|null 
     */
    public function getCreator() : ?string
    {
        return $this->creator;
    }

    /**
     * 设置 
     * @param string|null $creator 
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setCreator(string $creator = null) : DeviceOperationsManagementBean
    {
        $this->creator = $creator;
        $this->flagSet('creator');
        return $this;
    }
    
    /**
     * 获取 
     * @return int|null 
     */
    public function getIsDelete() : ?int
    {
        return $this->isDelete;
    }

    /**
     * 设置 
     * @param int|null $isDelete 
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setIsDelete(int $isDelete = null) : DeviceOperationsManagementBean
    {
        $this->isDelete = $isDelete;
        $this->flagSet('isDelete');
        return $this;
    }
    
    /**
     * 获取 更新时间
     * @return string|null 更新时间
     */
    public function getUpdateTime() : ?string
    {
        return $this->updateTime;
    }

    /**
     * 设置 更新时间
     * @param string|null $updateTime 更新时间
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setUpdateTime(string $updateTime = null) : DeviceOperationsManagementBean
    {
        $this->updateTime = $updateTime;
        $this->flagSet('updateTime');
        return $this;
    }
    
    /**
     * 获取 更新者
     * @return string|null 更新者
     */
    public function getUpdator() : ?string
    {
        return $this->updator;
    }

    /**
     * 设置 更新者
     * @param string|null $updator 更新者
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setUpdator(string $updator = null) : DeviceOperationsManagementBean
    {
        $this->updator = $updator;
        $this->flagSet('updator');
        return $this;
    }
    
    /**
     * 获取 是否结算服务费(0: 否, 1: 是)
     * @return int|null 是否结算服务费(0: 否, 1: 是)
     */
    public function getNeedServiceFee() : ?int
    {
        return $this->needServiceFee;
    }

    /**
     * 设置 是否结算服务费(0: 否, 1: 是)
     * @param int|null $needServiceFee 是否结算服务费(0: 否, 1: 是)
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setNeedServiceFee(int $needServiceFee = null) : DeviceOperationsManagementBean
    {
        $this->needServiceFee = $needServiceFee;
        $this->flagSet('needServiceFee');
        return $this;
    }
    
    /**
     * 获取 停止时间
     * @return string|null 停止时间
     */
    public function getStopTime() : ?string
    {
        return $this->stopTime;
    }

    /**
     * 设置 停止时间
     * @param string|null $stopTime 停止时间
     * @return DeviceOperationsManagementBean 当前对象
     */
    public function setStopTime(string $stopTime = null) : DeviceOperationsManagementBean
    {
        $this->stopTime = $stopTime;
        $this->flagSet('stopTime');
        return $this;
    }
    
    /**
     * 构造函数<br/><br/>
     * 表描述: 设备运维管理人员表<br/>
     * 表名: tp_device_operations_management
     * @param array $row 一条数据
     */
    public function __construct($row = [])
    {   
        $this->deviceId = isset($row['device_id']) ? $row['device_id'] : $this->deviceId;
        $this->adminId = isset($row['admin_id']) ? $row['admin_id'] : $this->adminId;
        $this->status = isset($row['status']) ? $row['status'] : $this->status;
        $this->startTime = isset($row['start_time']) ? $row['start_time'] : $this->startTime;
        $this->createTime = isset($row['create_time']) ? $row['create_time'] : $this->createTime;
        $this->creator = isset($row['creator']) ? $row['creator'] : $this->creator;
        $this->isDelete = isset($row['is_delete']) ? $row['is_delete'] : $this->isDelete;
        $this->updateTime = isset($row['update_time']) ? $row['update_time'] : $this->updateTime;
        $this->updator = isset($row['updator']) ? $row['updator'] : $this->updator;
        $this->needServiceFee = isset($row['need_service_fee']) ? $row['need_service_fee'] : $this->needServiceFee;
        $this->stopTime = isset($row['stop_time']) ? $row['stop_time'] : $this->stopTime;
    }

    /**
     * 附加上类的信息（注意在定义函数时需要指定对应的返回值的类型）
     * @param mixed $object 对象
     * @return DeviceOperationsManagementBean|null
     */
    public static function attachClassInfo($object) : ?DeviceOperationsManagementBean
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
        
        if ($includeAllFields === true || $this->isset('deviceId')) {
            $data['device_id'] = $this->getDeviceId();
        }
        
        if ($includeAllFields === true || $this->isset('adminId')) {
            $data['admin_id'] = $this->getAdminId();
        }
        
        if ($includeAllFields === true || $this->isset('status')) {
            $data['status'] = $this->getStatus();
        }
        
        if ($includeAllFields === true || $this->isset('startTime')) {
            $data['start_time'] = $this->getStartTime();
        }
        
        if ($includeAllFields === true || $this->isset('createTime')) {
            $data['create_time'] = $this->getCreateTime();
        }
        
        if ($includeAllFields === true || $this->isset('creator')) {
            $data['creator'] = $this->getCreator();
        }
        
        if ($includeAllFields === true || $this->isset('isDelete')) {
            $data['is_delete'] = $this->getIsDelete();
        }
        
        if ($includeAllFields === true || $this->isset('updateTime')) {
            $data['update_time'] = $this->getUpdateTime();
        }
        
        if ($includeAllFields === true || $this->isset('updator')) {
            $data['updator'] = $this->getUpdator();
        }
        
        if ($includeAllFields === true || $this->isset('needServiceFee')) {
            $data['need_service_fee'] = $this->getNeedServiceFee();
        }
        
        if ($includeAllFields === true || $this->isset('stopTime')) {
            $data['stop_time'] = $this->getStopTime();
        }
        
        return $data;
    }
}