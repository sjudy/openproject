#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2014 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

class JournalManager

  def self.is_journalized?(obj)
    not obj.nil? and obj.respond_to? :journals
  end

  def self.changed?(journable)
    if journable.journals.count > 0
      changed = attributes_changed? journable
      changed ||= association_changed? journable, "attachable", :attachments, :id, :attachment_id, :filename
      changed ||= association_changed? journable, "customizable", :custom_values, :custom_field_id, :custom_field_id, :value

      changed
    else
      true
    end
  end

  def self.attributes_changed?(journable)
    type = base_class(journable.class)
    current = valid_journal_attributes type, journable.attributes
    predecessor = journable.journals.last.data.journaled_attributes

    current = normalize_newlines(current)
    predecessor = normalize_newlines(predecessor)

    # we generally ignore changes from blank to blank
    return predecessor.map{|k,v| current[k.to_s] != v && (v.present? || current[k.to_s].present?)}
                      .inject(false) { |r, c| r || c }
  end

  def self.association_changed?(journable, journal_association, association, id, key, value)
    if journable.respond_to? association
      journal_assoc_name = "#{journal_association}_journals"
      changes = {}
      current = journable.send(association).map {|a| { key.to_s => a.send(id), value.to_s => a.send(value)} }
      predecessor = journable.journals.last.send(journal_assoc_name).map(&:attributes)

      current = remove_empty_associations(current, value.to_s)

      merged_journals = JournalManager.merge_reference_journals_by_id current, predecessor, key.to_s

      changes.merge! JournalManager.added_references(merged_journals, association.to_s, value.to_s)
      changes.merge! JournalManager.removed_references(merged_journals, association.to_s, value.to_s)
      changes.merge! JournalManager.changed_references(merged_journals, association.to_s, value.to_s)

      not changes.empty?
    else
      false
    end
  end

  # associations have value attributes ('value' for custom values and 'filename'
  # for attachments). This method ensures that blank value attributes are
  # treated like non-existing associations. Thus, this prevents that
  # non-existing associations (nil) are different to blank associations ("").
  # This would lead to false change information, otherwise.
  def self.remove_empty_associations(associations, value)
    associations.reject { |h| h.has_key?(value) && h[value].blank? }
  end

  def self.merge_reference_journals_by_id(current, predecessor, key)
      all_attachable_journal_ids = current.map { |j| j[key] } | predecessor.map { |j| j[key] }

      all_attachable_journal_ids.each_with_object({}) { |i, h| h[i] = [predecessor.detect { |j| j[key] == i },
                                                                       current.detect { |j| j[key] == i }] }
  end

  def self.added_references(merged_references, key, value)
    merged_references.select {|_, v| v[0].nil? and not v[1].nil?}
                     .each_with_object({}) { |k,h| h["#{key}_#{k[0]}"] = [nil, k[1][1][value]] }
  end

  def self.removed_references(merged_references, key, value)
    merged_references.select {|_, v| not v[0].nil? and v[1].nil?}
                             .each_with_object({}) { |k,h| h["#{key}_#{k[0]}"] = [k[1][0][value], nil] }
  end

  def self.changed_references(merged_references, key, value)
    merged_references.select {|_, v| not v[0].nil? and not v[1].nil? and v[0][value] != v[1][value]}
                     .each_with_object({}) { |k,h| h["#{key}_#{k[0]}"] = [k[1][0][value], k[1][1][value]] }

  end

  def self.recreate_initial_journal(type, journal, changed_data)
    if journal.data.nil?
      journal.data = create_journal_data journal.id, type, changed_data.except(:id)
    else
      journal.changed_data = changed_data
      journal.attachable_journals.delete_all
      journal.customizable_journals.delete_all
    end

    create_association_data journal.journable, journal

    journal.save!
    journal.reload
  end

  def self.add_journal(journable, user = User.current, notes = "")
    if is_journalized? journable
      journal_attributes = { journable_id: journable.id,
                             journable_type: journal_class_name(journable.class),
                             version: (journable.journals.count + 1),
                             activity_type: journable.send(:activity_type),
                             changed_data: journable.attributes.symbolize_keys }

      create_journal journable, journal_attributes, user, notes
    end
  end

  def self.create_journal(journable, journal_attributes, user = User.current,  notes = "")
    type = base_class(journable.class)
    extended_journal_attributes = journal_attributes.merge({ journable_type: journal_class_name(type) })
                                                    .merge({ notes: notes })
                                                    .except(:changed_data)
                                                    .except(:id)

    unless extended_journal_attributes.has_key? :user_id
      extended_journal_attributes[:user_id] = user.id
    end

    journal_attributes[:changed_data] = normalize_newlines(journal_attributes[:changed_data])

    journal = journable.journals.build extended_journal_attributes
    journal.data = create_journal_data journal.id, type, valid_journal_attributes(type, journal_attributes[:changed_data])

    create_association_data journable, journal

    journal
  end

  def self.valid_journal_attributes(type, changed_data)
    journal_class = journal_class type
    journal_class_attributes = journal_class.columns.map(&:name)

    valid_journal_attributes = changed_data.select {|k,v| journal_class_attributes.include?(k.to_s)}
    valid_journal_attributes.except 'id', 'updated_at', 'updated_on'
  end

  def self.create_journal_data(journal_id, type, changed_data)
    journal_class = journal_class type
    new_data = Hash[changed_data.map{|k,v| [k, (v.kind_of? Array) ? v.last : v]}]

    journal_class.new new_data
  end

  USER_DELETION_JOURNAL_BUCKET_SIZE = 1000;

  def self.update_user_references(current_user_id, substitute_id)
    foreign_keys = ['author_id', 'user_id', 'assigned_to_id', 'responsible_id']

    # as updating the journals will take some time we do it in batches
    # so that journals created later are also accounted for
    while (journal_subset = Journal.all(:conditions => ["id > ?", current_id ||= 0],
                                        :order => "id ASC",
                                        :limit => USER_DELETION_JOURNAL_BUCKET_SIZE)).size > 0 do

      # change user reference in data fields
      journal_subset.each do |journal|
        foreign_keys.each do |foreign_key|
          if journal.data.respond_to? foreign_key
            journal.data.send "#{foreign_key}=", substitute_id if journal.data.send(foreign_key) == current_user_id
          end
        end

        # change journal user
        journal.user_id = substitute_id if journal.user_id = current_user_id

        journal.save if journal.data.changed?
      end

      current_id = journal_subset.map(&:id).max
    end
  end

  def self.journal_class(type)
    namespace = type.name.deconstantize

    if namespace == 'Journal'
      type
    else
      "Journal::#{journal_class_name(type)}".constantize
    end
  end

  def self.journaled_class(journal_type)
    namespace = journal_type.name.deconstantize

    if namespace == 'Journal'
      class_name = journal_type.name.demodulize
      class_name.gsub('Journal', '').constantize
    else
      journal_type
    end
  end

  def self.normalize_newlines(data)
    data.each_with_object({}) { |e, h| h[e[0]] = (e[1].kind_of?(String) ? e[1].gsub(/\r\n/,"\n")
                                                                        : e[1]) }
  end

  private

  def self.journal_class_name(type)
    "#{base_class(type).name}Journal"
  end

  def self.base_class(type)
    supertype = type.ancestors.find{|a| a != type and a.is_a? Class}

    supertype = type if supertype == ActiveRecord::Base

    supertype
  end

  def self.create_association_data(journable, journal)
    create_attachment_data journable, journal if journable.respond_to? :attachments
    create_custom_field_data journable, journal if journable.respond_to? :custom_values
  end

  def self.create_attachment_data(journable, journal)
    journable.attachments.each do |a|
      journal.attachable_journals.build attachment: a, filename: a.filename
    end
  end

  def self.create_custom_field_data(journable, journal)
    # Consider only custom values with non-blank values. Otherwise,
    # non-existing custom values are different to custom values with an empty
    # value.
    journable.custom_values.select { |c| !c.value.blank? }.each do |cv|
      journal.customizable_journals.build custom_field_id: cv.custom_field_id, value: cv.value
    end
  end
end
