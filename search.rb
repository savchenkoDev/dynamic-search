def search
  answer = {}
  query = query_construct
  @announcings = Announcing.find_by_sql(query).paginate(page: params[:page], per_page: 21)
  @announcings_count = Announcing.find_by_sql(query).count
  answer[:page_count] = @announcings_count / 21 + 1
  answer[:items] = ActiveModel::SerializableResource.new(@announcings).serializable_hash

  render json: answer
end

private

def query_construct()
  query_params = []
  checkboxes = {}
  query = 'SELECT a.* FROM announcings AS a FULL OUTER JOIN properties AS p ON p.announcing_id = a.id'
  query << ' WHERE ' if params[:announcing].present? || params[:properties].present?
  params[:announcing]&.each_pair do |key, value|
    if key == 'role' && value != 'all'
      query_params << "a.user_id IN (#{User.where(role: value).pluck(:id).join(', ')})"
    else
      value = range_prepare(value, key)
      query_params << "a.#{key} #{value}" if value.present?
    end
  end
  params[:properties]&.each_pair do |key, value|
    if value[:kind].to_i.zero?
      value = range_prepare(value[:value])

      query_params << "(p.field_id = #{key} AND p.value #{value})"
    else
      checkboxes[key] ||= []
      values = value[:value].is_a?(Array) ? value[:value] : value[:value].values
      checkboxes[key] << values
    end
  end
  checkboxes.each_pair do |key, value|
    query_params << "(p.field_id = #{key} AND p.value IN (#{value.join(',')}))"
  end
  query << query_params.join(' AND ') + ' GROUP BY a.id ORDER BY a.created_at'
end

def range_prepare(value, key = '')
  return '' if value == 'all' || value.blank?
  return "= #{value}" if value.is_a?(Integer) || value.is_a?(String)

  if key == 'created_at'
    min = value[:min].present? ? Date.parse(value[:min]) : nil
    max = value[:max].present? ? Date.parse(value[:max]) : nil
  else
    min = value[:min] || nil
    max = value[:max] || nil
  end
  if min.present? && max.present?
    key == 'created_at' ? "BETWEEN '#{min}' AND '#{max}'" : "BETWEEN #{min} AND #{max}"
  elsif max.present?
    key == 'created_at' ? "<= '#{max}'" : "<= #{max}"
  elsif min.present?
    key == 'created_at' ? ">= '#{min}'" : ">= #{min}"
  end
end
