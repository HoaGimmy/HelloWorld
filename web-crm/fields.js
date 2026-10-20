// [key, Vietnamese label, input type, required]
const customer=['customer_id','Khách hàng','customers',true];
const project=['project_id','Công trình','projects'];
const note=['note','Ghi chú','textarea'];
export const fields={
 customers:[['name','Tên khách hàng','text',true],['phone','Số điện thoại','tel'],['zalo','Zalo'],['address','Địa chỉ'],['source','Nguồn khách'],['stage','Hành trình','stage'],['need','Nhu cầu','textarea'],['budget','Ngân sách (VNĐ)','number'],note],
 activities:[customer,['type','Loại chăm sóc'],['title','Tiêu đề','text',true],['content','Nội dung','textarea']],
 tasks:[['customer_id','Khách hàng','customers'],['title','Tên công việc','text',true],['due_date','Hạn công việc','date',true],['priority','Ưu tiên'],['completed','Hoàn thành','boolean'],note],
 appointments:[['customer_id','Khách hàng','customers'],['title','Tên lịch hẹn','text',true],['starts_at','Thời gian hẹn','datetime-local',true],['duration_minutes','Thời lượng (phút)','number'],['location','Địa điểm'],['completed','Hoàn thành','boolean'],note],
 projects:[customer,['name','Tên công trình','text',true],['address','Địa chỉ'],['category','Hạng mục'],['aluminum_brand','Hãng nhôm'],['aluminum_type','Loại nhôm'],['glass_type','Loại kính'],['aluminum_system','Hệ nhôm'],['accessory','Phụ kiện'],['area_m2','Khối lượng (m²)','number'],['quantity','Số lượng (bộ)','number'],['status','Tiến độ'],['production_date','Ngày sản xuất','date'],['install_date','Ngày lắp đặt','date'],note],
 quotes:[customer,project,['code','Mã báo giá','text',true],['amount','Giá trị (VNĐ)','number'],['status','Trạng thái'],['valid_until','Hiệu lực đến','date'],note],
 contracts:[customer,project,['code','Mã hợp đồng','text',true],['value','Giá trị hợp đồng (VNĐ)','number'],['signed_at','Ngày ký','date'],['install_date','Ngày lắp đặt','date'],['warranty_months','Bảo hành (tháng)','number'],['status','Trạng thái'],['profit_percent','Lợi nhuận (%)','percent'],['company_cost_percent','Chi phí công ty (%)','percent'],['commission_share_percent','Tỷ lệ hưởng hoa hồng (%)','percent'],['commission_received','Hoa hồng đã nhận (VNĐ)','number'],note],
 payments:[customer,['contract_id','Hợp đồng','contracts',true],['amount','Số tiền (VNĐ)','number',true],['paid_at','Ngày thu','date',true],['method','Phương thức'],note]
};
