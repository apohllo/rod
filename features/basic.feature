Feature: Store and load small amount of data from one class
  In order to ensure basic functionality, ROD should
  allow to store and load data for one simple class.

  @wip
  Scenario: class with one field
      Rod should allow to store in the DB instances of a class with one field
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String
      end
      """
    When the database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'

    When database is created
    And I create a Caveman
    And her name is 'Wilma'
    And I store her in the database
    And I create another Caveman
    And his name is 'Barney'
    And I store him in the database
    Then there should be 2 Caveman(s)
    And the name of the first Caveman should be 'Wilma'
    And the name of the second Caveman should be 'Barney'
    And the third Caveman should not exist

  Scenario: class with every type of field
      Rod should allow to store in the DB instances of a class
      having fields of each type
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String
        attribute :age, Integer
        attribute :identifier, Integer
        attribute :height, Float
        attribute :account_balance, Float
        attribute :symbol, Symbol
        attribute :empty_string, String
        attribute :empty_symbol, Symbol
      end
      """
    When the database is created
    And I create a Caveman
    And his name is 'Fred'
    And his age is '25'
    And his identifier is '111222333'
    And his height is '1.86'
    And his account_balance is '-0.00000001'
    And his symbol is ':fred'
    # nil is converted to an empty string, consider using object field
    # if you wish to store nil for string fields
    And his empty_string is nil
    # The field is not set to nil, but we assume that not set fields of
    # type object are nils.
    #And his empty_object is nil
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'
    And the age of the first Caveman should be '25'
    And the identifier of the first Caveman should be '111222333'
    And the height of the first Caveman should be '1.86'
    And the account_balance of the first Caveman should be '-0.00000001'
    And the symbol of the first Caveman should be ':fred'
    And the empty_string of the first Caveman should be ''
    And the empty_symbol of the first Caveman should be nil

  Scenario: instance with string containing 0
      Rod should allow to store in the DB string values
      containing characters equal to 0 (not the number but value)
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String
      end
      """
    When the database is created
    And I create a Caveman
    And his name is 'Fred\0Fred'
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred\0Fred'

    When the database is created
    And I create a Caveman
    And his name is 'Fred\0' multiplied 30000 times
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred\0' multiplied 30000 times

  Scenario: reading fields while objects are created
      Rod should allow to read values of initialized fields of instances, before and after
      the instance is stored to the DB.
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String, :default => ""
        attribute :age, Integer, :default => 0
        attribute :identifier, Integer, :default => 0
        attribute :height, Float, :default => 0.0
      end
      """
    When the database is created
    And I create a Caveman
    And his name is 'Fred'
    And his age is '25'
    And his identifier is '111222333'
    And his height is '1.86'
    Then his name should be 'Fred'
    And his age should be '25'
    And his identifier should be '111222333'
    And his height should be '1.86'

    When the database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I remember the first Caveman
    And I create another Caveman
    And his name is 'Fred'
    And I store him in the database 4000 times
    Then the name of the remembered instance should be 'Fred'

  Scenario: reading properties of fresh object
      Rod should allow to read values of uninitialized fields of instances,
      before the instance is stored to the DB.
    Given the class space is cleared
    And the default database is initialized
    And the following classes are defined:
      """
      class Item
        include Virtus
      end

      class Caveman
        include Rod.resource

        attribute :name, String, :default => ""
        attribute :age, Integer, :default => 0
        attribute :identifier, Integer, :default => 0
        attribute :height, Float, :default => 0.0
        attribute :symbol, Symbol
        attribute :item, Item
        attribute :items, Array[Item]
      end
      """
    When database is created
    And I create a Caveman
    And I fetch the first Caveman created
    Then his name should be ''
    And his age should be '0'
    And his identifier should be '0'
    And his height should be '0'
    And his symbol should be nil
    And his item should be nil
    And his items should be empty

  Scenario: referential integrity and simple indexing
      Rod should allow to access objects via simple indexing
      (i.e. Model[index]).
      It should also impose referential integrity for objects
      which are accessed via their indices.
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String
      end
      """
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    Then the first Caveman should be identical with the first Caveman
    And the first Caveman should be equal with the instance

  Scenario: model without instances
      A model without instances should be treated fine.
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String
      end
      """
    When database is created
    And I reopen database for reading
    Then there should be 0 Caveman(s)

  Scenario: model without instances with indexed field
      A model without instances but with indexed field should be treated fine.
    Given the class space is cleared
    And the default database is initialized
    And the following classes are defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String, :index => :hash
      end

      class Automobile
        include Rod.resource

        attribute :name, String, :index => :hash
      end
      """
    When database is created
    And I create a Caveman
    And his name is 'Fred'
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 0 Automobile(s)

  Scenario: ActiveRecord-style initialization
      A new instance of a model should accept hash of key-value pairs,
      used to initialize its fields.
    Given the class space is cleared
    And the default database is initialized
    And the following class is defined:
      """
      class Caveman
        include Rod.resource

        attribute :name, String
        attribute :surname, String
      end
      """
    When database is created
    And I create a Caveman with 'Fred' name and 'Flintstone' surname
    And I store him in the database
    Then there should be 1 Caveman
    And his name should be 'Fred'
    And his surname should be 'Flintstone'

    When database is created
    And I create a Caveman with 'Fred' name and 'Flintstone' age
    Then NilClass should be raised
