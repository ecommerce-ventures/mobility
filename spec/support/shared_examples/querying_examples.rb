shared_examples_for "AR Model with translated scope" do |model_class_name, a1=:amount, a2=:tax|
  let(:backend_name) { model_class.mobility_modules.first.backend_name }
  let(:model_class) { model_class_name.constantize }
  let(:query_scope) { model_class.i18n }
  let(:ordered_results) { query_scope.order("#{model_class.table_name}.id asc") }

  describe ".where" do
    context "querying on one translated attribute" do
      before do
        @instance1 = model_class.create(a1 => 100)
        @instance2 = model_class.create(a1 => 200)
        @instance3 = model_class.create(a1 => 300, published: true)
        @instance4 = model_class.create(a1 => 300, published: false)
        @instance5 = model_class.create(a1 => 100, published: true)
      end

      it "returns correct result searching on unique attribute value" do
        expect(query_scope.where(a1 => 200)).to eq([@instance2])
      end

      it "returns correct results when query matches multiple records" do
        expect(query_scope.where(a1 => 100)).to match_array([@instance1, @instance5])
      end

      it "returns correct result when querying on translated and untranslated attributes" do
        expect(query_scope.where(a1 => 300, published: true)).to eq([@instance3])
      end

      it "returns correct result when querying on nil values" do
        instance = model_class.create(a1 => nil)
        expect(query_scope.where(a1 => nil)).to eq([instance])
      end

      context "with content in different currencies" do
        before do
          Mobility.with_currency(:jpy) do
            @ja_instance1 = model_class.create(a1 => 400)
            @ja_instance2 = model_class.create(a1 => 100)
          end
        end

        it "returns correct result when querying on same attribute value in different currency" do
          expect(query_scope.where(a1 => 100)).to match_array([@instance1, @instance5])

          Mobility.with_currency(:jpy) do
            expect(query_scope.where(a1 => 400)).to eq([@ja_instance1])
            expect(query_scope.where(a1 => 100)).to eq([@ja_instance2])
          end
        end

        it "returns correct result when querying with currency option" do
          expect(query_scope.where(a1 => 100, currency: :usd)).to match_array([@instance1, @instance5])
          expect(query_scope.where(a1 => 400, currency: :jpy)).to eq([@ja_instance1])
          expect(query_scope.where(a1 => 100, currency: :jpy)).to eq([@ja_instance2])
        end

        it "returns correct result when querying with currency option twice in separate clauses" do
          @ja_instance1.update(a1 => 700)
          expect(query_scope.where(a1 => 400, currency: :jpy).where(a1 => 700, currency: :usd)).to eq([@ja_instance1])
          expect(query_scope.where(a1 => 100, currency: :jpy).where(a1 => nil, currency: :usd)).to eq([@ja_instance2])
        end
      end

      context "with exists?" do
        it "returns correct result searching on unique attribute value" do
          aggregate_failures do
            expect(query_scope.where(a1 => 200).exists?).to eq(true)
            expect(query_scope.where(a1 => "aaa").exists?).to eq(false)
          end
        end
      end
    end

    context "with two translated attributes" do
      before do
        @instance1 = model_class.create(a1 => 100                                       )
        @instance2 = model_class.create(a1 => 100, a2 => 1200                  )
        @instance3 = model_class.create(a1 => 100, a2 => 1200, published: false)
        @instance4 = model_class.create(             a2 => 1200                  )
        @instance5 = model_class.create(a1 => 200, a2 => 600                  )
        @instance6 = model_class.create(a1 => 200,                      published: true )
      end

      # @note Regression spec
      it "does not modify scope in-place" do
        query_scope.where(a1 => 100)
        expect(query_scope.to_sql).to eq(model_class.all.to_sql)
      end

      it "returns correct results querying on one attribute" do
        expect(query_scope.where(a1 => 100)).to match_array([@instance1, @instance2, @instance3])
        expect(query_scope.where(a2 => 1200)).to match_array([@instance2, @instance3, @instance4])
      end

      it "returns correct results querying on two attributes in single where call" do
        expect(query_scope.where(a1 => 100, a2 => 1200)).to match_array([@instance2, @instance3])
      end

      it "returns correct results querying on two attributes in separate where calls" do
        expect(query_scope.where(a1 => 100).where(a2 => 1200)).to match_array([@instance2, @instance3])
      end

      it "returns correct result querying on two translated attributes and untranslated attribute" do
        expect(query_scope.where(a1 => 100, a2 => 1200, published: false)).to eq([@instance3])
      end

      it "works with nil values" do
        expect(query_scope.where(a1 => 100, a2 => nil)).to eq([@instance1])
        expect(query_scope.where(a1 => 100).where(a2 => nil)).to eq([@instance1])
        instance = model_class.create
        expect(query_scope.where(a1 => nil, a2 => nil)).to eq([instance])
      end

      context "with content in different currencies" do
        before do
          Mobility.with_currency(:jpy) do
            @ja_instance1 = model_class.create(a1 => 400, a2 => 1300)
            @ja_instance2 = model_class.create(a1 => 100,    a2 => 1200   )
            @ja_instance3 = model_class.create(a1 => 100                           )
            @ja_instance4 = model_class.create(                a2 => 100           )
          end
        end

        it "returns correct result when querying on same attribute values in different currency" do
          expect(query_scope.where(a1 => 100, a2 => 1200)).to match_array([@instance2, @instance3])
          expect(query_scope.where(a1 => 100, a2 => nil)).to eq([@instance1])

          Mobility.with_currency(:jpy) do
            expect(query_scope.where(a1 => 100)).to match_array([@ja_instance2, @ja_instance3])
            expect(query_scope.where(a1 => 100, a2 => 1200)).to eq([@ja_instance2])
            expect(query_scope.where(a1 => 400, a2 => 1300)).to eq([@ja_instance1])
          end
        end
      end
    end

    context "with array of values" do
      before do
        @instance1 = model_class.create(a1 => 100)
        @instance2 = model_class.create(a1 => 200)
        @instance3 = model_class.create(a1 => 300)
        @instance4 = model_class.create(a1 => nil)

        Mobility.with_currency(:jpy) do
          @ja_instance1 = model_class.create(a1 => 100)
        end
      end

      it "returns records with matching translated attribute values" do
        expect(query_scope.where(a1 => [100, 300])).to match_array([@instance1, @instance3])
        expect(query_scope.where(a1 => [100, nil])).to match_array([@instance1, @instance4, @ja_instance1])
      end

      it "collapses clauses in array of values" do
        instance = model_class.create(a1 => 300)
        expect(query_scope.where(a1 => [100, nil, nil])).to match_array([@instance1, @instance4, @ja_instance1])
        expect(query_scope.where(a1 => [100, 100, nil])).to match_array([@instance1, @instance4, @ja_instance1])
        aggregate_failures do
          expect(query_scope.where(a1 => [100, nil]).to_sql).to eq(query_scope.where(a1 => [100, nil, nil]).to_sql)
          expect(query_scope.where(a1 => [100, nil]).to_sql).to eq(query_scope.where(a1 => [100, 100, nil]).to_sql)
        end
      end
    end

    context "with single table inheritance" do
      let(:sti_model) { Class.new(model_class) }

      it "works with sti model" do
        instance = sti_model.create(a1 => 100)
        sti_model.i18n.where(a1 => 100)
        expect(sti_model.i18n.where(a1 => 100)).to match_array([instance])
      end
    end
  end

  describe ".not" do
    before do
      @instance1 = model_class.create(a1 => 100                                       )
      @instance2 = model_class.create(a1 => 100, a2 => 1200                  )
      @instance3 = model_class.create(a1 => 100, a2 => 1200, published: false)
      @instance4 = model_class.create(             a2 => 1200                  )
      @instance5 = model_class.create(a1 => 200, a2 => 600, published: true )
      @instance6 = model_class.create(a1 => 200, a2 => 900, published: false)
      @instance7 = model_class.create(                                  published: true )
    end

    # @note Regression spec
    it "does not modify scope in-place" do
      query_scope.where.not(a1 => nil)
      expect(query_scope.to_sql).to eq(model_class.all.to_sql)
    end

    it "works with nil values" do
      expect(query_scope.where.not(a1 => nil)).to match_array([@instance1, @instance2, @instance3, @instance5, @instance6])
      expect(query_scope.where.not(a1 => nil).where.not(a2 => nil)).to match_array([@instance2, @instance3, @instance5, @instance6])
      expect(query_scope.where(a1 => nil).where.not(a2 => nil)).to eq([@instance4])
    end

    it "returns record without translated attribute value" do
      expect(query_scope.where.not(a1 => 100)).to match_array([@instance5, @instance6])
    end

    it "returns record without set of translated attribute values" do
      expect(query_scope.where.not(a1 => 100, a2 => 900)).to match_array([@instance5])
    end

    it "works in combination with untranslated attributes" do
      expect(query_scope.where.not(a1 => 100, published: true)).to eq([@instance6])
    end

    it "works with array of values" do
      instance = model_class.create(a1 => 300)
      aggregate_failures do
        expect(query_scope.where.not(a1 => [100, 200])).to match_array([instance])
        expect(query_scope.where.not(a1 => [100, nil])).to match_array([instance, @instance5, @instance6])
      end
    end

    it "collapses clauses in array of values" do
      instance = model_class.create(a1 => 300)
      expect(query_scope.where.not(a1 => [100, nil, nil])).to match_array([instance, @instance5, @instance6])
      expect(query_scope.where.not(a1 => [100, 100, nil])).to match_array([instance, @instance5, @instance6])
      aggregate_failures do
        expect(query_scope.where.not(a1 => [100, nil]).to_sql).to eq(query_scope.where.not(a1 => [100, nil, nil]).to_sql)
        expect(query_scope.where.not(a1 => [100, nil]).to_sql).to eq(query_scope.where.not(a1 => [100, 100, nil]).to_sql)
      end
    end

    it "uses IN when matching array of two or more non-nil values" do
      aggregate_failures "where" do
        expect(query_scope.where(a1 => [100, 200]).to_sql).to match /\sIN\s/
        expect(query_scope.where(a1 => [100, 200, nil]).to_sql).to match /\sIN\s/
        expect(query_scope.where(a1 => [100, nil]).to_sql).not_to match /\sIN\s/
        expect(query_scope.where(a1 => 100).to_sql).not_to match /\sIN\s/
        expect(query_scope.where(a1 => nil).to_sql).not_to match /\sIN\s/
      end

      aggregate_failures "where not" do
        expect(query_scope.where.not(a1 => [100, 200]).to_sql).to match /\sIN\s/
        expect(query_scope.where.not(a1 => [100, 200, nil]).to_sql).to match /\sIN\s/
        expect(query_scope.where.not(a1 => [100, nil]).to_sql).not_to match /\sIN\s/
        expect(query_scope.where.not(a1 => 100).to_sql).not_to match /\sIN\s/
        expect(query_scope.where.not(a1 => nil).to_sql).not_to match /\sIN\s/
      end
    end
  end

  describe ".order" do
    let!(:i) do
      [
        model_class.create(a1 => 101),
        model_class.create(a1 => 103, a2 => 102),
        model_class.create(a1 => 102, a2 => 203),
        model_class.create(a1 => 104, a2 => 202)
      ]
    end

    it "orders records correctly with string argument" do
      expect(query_scope.order(a1.to_s)).to eq([i[0], i[2], i[1], i[3]])
    end

    it "orders records correctly with symbol argument" do
      expect(query_scope.order(a1.to_sym)).to eq([i[0], i[2], i[1], i[3]])
    end

    it "orders records correctly with 1-key hash argument" do
      aggregate_failures "one attribute" do
        expect(query_scope.order(a1 => :asc)).to eq([i[0], i[2], i[1], i[3]])
        expect(query_scope.order(a1 => :desc)).to eq([i[3], i[1], i[2], i[0]])
      end
    end

    it "orders records correctly with 2-key hash argument" do
      skip "Not supported by #{backend_name}" if [:table, :key_value].include?(backend_name)

      added = model_class.create(a1 => 103, a2 => 103)
      expect(query_scope.order(a1 => :desc, a2 => :asc)).to eq([i[3], i[1], added, i[2], i[0]])
    end

    it "handles untranslated attributes" do
      expect { query_scope.order(published: :desc) }.not_to raise_error
    end

    it "does not modify original hash" do
      hash = { a1 => :asc }
      expect { query_scope.order(hash) }.not_to change { hash }
    end
  end

  describe ".pluck", rails_version_geq: '5.0' do
    before do
      [[101, 204, true],
       [103, 201, false],
       [101, 202, true],
       [102, 203, false],
       [104, 202, nil]].each do |(val1, val2, val3)|
        model_class.create(a1 => val1, a2 => val2, :published => val3)
      end
    end

    it "plucks individual attribute values" do
      expect(ordered_results.pluck(a1)).to eq([101, 103, 101, 102, 104])
    end

    it "plucks pairs of attribute values" do
      expect(ordered_results.pluck(a1, a2)).to eq(
        [[101, 204],
         [103, 201],
         [101, 202],
         [102, 203],
         [104, 202]]
      )
    end

    it "plucks translated attributes mixed with untranslated attributes" do
      expect(ordered_results.pluck(a1, :published, a2)).to eq(
        [[101, true,  204],
         [103, false, 201],
         [101, true,  202],
         [102, false, 203],
         [104, nil,   202]]
      )
    end

    it "plucks untranslated attributes only" do
      expect(ordered_results.pluck(:published)).to eq([true, false, true, false, nil])
    end

    it "works with nil values" do
      model_class.create(a1 => nil, a2 => 205)
      model_class.create(a1 => 105, a2 => nil)
      expect(ordered_results.pluck(a1, a2)).to eq(
        [[101, 204],
         [103, 201],
         [101, 202],
         [102, 203],
         [104, 202],
         [nil,    205],
         [105, nil   ]]
      )
    end
  end

  describe ".select/.group", rails_version_geq: '5.0' do
    before do
      [[100, 300, true],
       [100, 300, false],
       [200, 300, true],
       [200, 100, false],
       [200, 100, nil]].each do |(val1, val2, val3)|
        model_class.create(a1 => val1, a2 => val2, :published => val3)
      end
    end

    describe "selecting translated attributes" do
      it "returns value from attribute methods on results" do
        selected = ordered_results.select(a1)
        expect(selected[0].send(a1)).to eq(100)
        expect(selected[1].send(a1)).to eq(100)
        expect(selected[2].send(a1)).to eq(200)
        expect(selected[3].send(a1)).to eq(200)
        expect(selected[4].send(a1)).to eq(200)
      end
    end

    describe "counting translated attributes" do
      it "counts total results" do
        selected = query_scope.select(a1)
        expect(selected.count).to eq(5)
      end

      it "works with count and group" do
        selected = query_scope.select(a1).group(a1)
        expect(selected.count).to eq({ 100 => 2, 200 => 3 })
      end

      it "works with count and group on two attributes" do
        selected = query_scope.select(a1).group(a1, a2)
        expect(selected.count).to eq({ [100, 300] => 2, [200, 300] => 1, [200, 100] => 2 })
      end
    end
  end

  describe "Arel queries" do
    # Shortcut for passing block to e.g. Post.i18n
    def query(*args, &block); model_class.i18n(*args, &block); end

    context "single-block querying" do
      let!(:i) { [
        model_class.create(a1 => 100             ),
        model_class.create(                        ),
        model_class.create(             a2 => 200),
        model_class.create(             a2 => 100),
        model_class.create(a1 => 200             ),
        model_class.create(a1 => 100, a2 => 200),
        model_class.create(a1 => 100, a2 => 300)
      ] }

      describe "equality" do
        it "handles (a EQ 'foo')" do
          expect(query { __send__(a1).eq(100) }).to match_array([i[0], *i[5..6]])
        end

        it "handles (a EQ NULL)" do
          expect(query { __send__(a1).eq(nil) }).to match_array(i[1..3])
        end

        it "handles (a EQ b)" do
          matching = [
            model_class.create(a1 => 100, a2 => 100),
            model_class.create(a1 => 200, a2 => 200)
          ]
          expect(query { __send__(a1).eq(__send__(a2)) }).to match_array(matching)
        end

        context "with currency option" do
          it "handles (a EQ 'foo')" do
            post1 = model_class.new(a1 => 700, a2 => 800)
            Mobility.with_currency(:jpy) do
              post1.send("#{a1}=", 400)
              post1.send("#{a2}=", 500)
            end
            post1.save

            post2 = model_class.new(a1 => 900)
            Mobility.with_currency(:gbp) { post2.send("#{a1}=", 1000) }
            post2.save

            expect(query(currency: :usd) { __send__(a1).eq(700) }).to match_array([post1])
            expect(query(currency: :usd) { __send__(a2).eq(800) }).to match_array([post1])
            expect(query(currency: :jpy) { __send__(a1).eq(400) }).to match_array([post1])
            expect(query(currency: :jpy) { __send__(a2).eq(500) }).to match_array([post1])
            expect(query(currency: :usd) { __send__(a1).eq(900) }).to match_array([post2])
            expect(query(currency: :gbp) { __send__(a1).eq(1000) }).to match_array([post2])
          end
        end
      end

      describe "not equal" do
        it "handles (a NOT EQ 100)" do
          expect(query { __send__(a1).not_eq(100) }).to match_array([i[4]])
        end

        it "handles (a NOT EQ NULL)" do
          expect(query { __send__(a1).not_eq(nil) }).to match_array([i[0], *i[4..6]])
        end

        context "with AND" do
          it "handles ((a NOT EQ NULL) AND (b NOT EQ NULL))" do
            expect(query {
              __send__(a1).not_eq(nil).and(__send__(a2).not_eq(nil))
            }).to match_array(i[5..6])
          end
        end

        context "with OR" do
          it "handles ((a NOT EQ NULL) OR (b NOT EQ NULL))" do
            expect(query {
              __send__(a1).not_eq(nil).or(__send__(a2).not_eq(nil))
            }).to match_array([i[0], *i[2..6]])
          end
        end
      end

      describe "AND" do
        it "handles (a AND b)" do
          expect(query {
            __send__(a1).eq(100).and(__send__(a2).eq(200))
          }).to match_array([i[5]])
        end

        it "handles (a AND b), where a is NULL-valued" do
          expect(query {
            __send__(a1).eq(nil).and(__send__(a2).eq(200))
          }).to match_array([i[2]])
        end

        it "handles (a AND b), where both a and b are NULL-valued" do
          expect(query {
            __send__(a1).eq(nil).and(__send__(a2).eq(nil))
          }).to match_array([i[1]])
        end
      end

      describe "OR" do
        it "handles (a OR b) on same attribute" do
          expect(query {
            __send__(a1).eq(100).or(__send__(a1).eq(200))
          }).to match_array([i[0], *i[4..6]])
        end

        it "handles (a OR b) on same attribute, where a is NULL-valued" do
          expect(query {
            __send__(a1).eq(nil).or(__send__(a1).eq(100))
          }).to match_array([*i[0..3], *i[5..6]])
        end

        it "handles (a OR b) on two attributes" do
          expect(query {
            __send__(a1).eq(100).or(__send__(a2).eq(200))
          }).to match_array([i[0], i[2], *i[5..6]])
        end

        it "handles (a OR b) on two attributes, where a is NULL-valued" do
          expect(query {
            __send__(a1).eq(nil).or(__send__(a2).eq(200))
          }).to match_array([*i[1..2], i[3], i[5]])
        end

        it "handles (a OR b) on two attributes, where both a and b are NULL-valued" do
          expect(query {
            __send__(a1).eq(nil).or(__send__(a2).eq(nil))
          }).to match_array(i[0..4])
        end
      end

      describe "combination of AND and OR" do
        it "handles a AND (b OR c)" do
          expect(query {
            __send__(a1).eq(100).and(
              __send__(a2).eq(200).or(__send__(a2).eq(300)))
          }).to match_array(i[5..6])
        end

        it "handles a AND (b OR c), where c is NULL-valued" do
          expect(query {
            __send__(a1).eq(100).and(
              __send__(a2).eq(200).or(__send__(a2).eq(nil)))
          }).to match_array([i[0], i[5]])
        end

        it "handles (a AND b) OR (c AND d), where b and d are NULL-valued" do
          expect(query {
            __send__(a1).eq(100).or(__send__(a1).eq(nil)).and(
              __send__(a2).eq(300).or(__send__(a2).eq(nil)))
          }).to match_array([*i[0..1], i[6]])
        end
      end
    end

    context "multi-block querying" do
      it "combines multiple currencies with non-nil values" do
        post1 = model_class.new(a1 => 700, a2 => 800)
        Mobility.with_currency(:jpy) do
          post1.send("#{a1}=", 400)
          post1.send("#{a2}=", 500)
        end
        post1.save

        post2 = model_class.new(a1 => 900)
        Mobility.with_currency(:gbp) { post2.send("#{a1}=", 1000) }
        post2.save

        aggregate_failures do
          expect(
            query(currency: :usd) { |usd|
              query(currency: :jpy) { |jpy|
                usd.__send__(a1).eq(700).and(jpy.__send__(a2).eq(500))
              }
            }
          ).to match_array([post1])

          expect(
            query(currency: :usd) { |usd|
              query(currency: :gbp) { |gbp|
                usd.__send__(a1).eq(900).and(gbp.__send__(a1).eq(1000))
              }
            }
          ).to match_array([post2])
        end
      end

      it "combines multiple currencies with nil and non-nil values" do
        post1 = model_class.new(a1 => 700)
        Mobility.with_currency(:jpy) { post1.send("#{a1}=", 400) }
        post1.save

        post2 = model_class.create(a1 => 700)

        expect(
          query(currency: :usd) { |usd|
            query(currency: :jpy) { |jpy|
              usd.__send__(a1).eq(700).and(jpy.__send__(a1).eq(nil))
            }
          }
        ).to match_array([post2])
      end
    end
  end
end

shared_examples_for "Sequel Model with translated dataset" do |model_class_name, a1=:title, a2=:content|
  let(:model_class) { constantize(model_class_name) }
  let(:table_name) { model_class.table_name }
  let(:query_scope) { model_class.i18n }
  let(:backend_name) { model_class.mobility_modules.first.backend_name }

  describe ".where" do
    context "querying on one translated attribute" do
      before do
        @instance1 = model_class.create(a1 => 100)
        @instance2 = model_class.create(a1 => 200)
        @instance3 = model_class.create(a1 => 300, :published => true)
        @instance4 = model_class.create(a1 => 300, :published => false)
        @instance5 = model_class.create(a1 => 100, :published => true)
      end

      it "returns correct result searching on unique attribute value" do
        expect(query_scope.where(a1 => 200).select_all(table_name).all).to eq([@instance2])
      end

      it "returns correct results when query matches multiple records" do
        expect(query_scope.where(a1 => 100).select_all(table_name).all).to match_array([@instance1, @instance5])
      end

      it "returns correct result when querying on translated and untranslated attributes" do
        expect(query_scope.where(a1 => 300, :published => true).select_all(table_name).all).to eq([@instance3])
      end

      it "returns correct result when querying on nil values" do
        instance = model_class.create(a1 => nil)
        expect(query_scope.where(a1 => nil).select_all(table_name).all).to eq([instance])
      end

      context "with content in different currencies" do
        before do
          Mobility.with_currency(:jpy) do
            @ja_instance1 = model_class.create(a1 => 400)
            @ja_instance2 = model_class.create(a1 => 100)
          end
        end

        it "returns correct result when querying on same attribute value in different currency" do
          expect(query_scope.where(a1 => 100).select_all(table_name).all).to match_array([@instance1, @instance5])

          Mobility.with_currency(:jpy) do
            expect(query_scope.where(a1 => 400).select_all(table_name).all).to eq([@ja_instance1])
            expect(query_scope.where(a1 => 100).select_all(table_name).all).to eq([@ja_instance2])
          end
        end

        it "returns correct result when querying with currency option" do
          expect(query_scope.where(a1 => 100, currency: :usd).select_all(table_name).all).to match_array([@instance1, @instance5])
          expect(query_scope.where(a1 => 400, currency: :jpy).select_all(table_name).all).to eq([@ja_instance1])
          expect(query_scope.where(a1 => 100, currency: :jpy).select_all(table_name).all).to eq([@ja_instance2])
        end

        it "returns correct result when querying with currency option twice in separate clauses" do
          @ja_instance1.update(a1 => 700)
          @ja_instance1.reload
          expect(query_scope.where(a1 => 400, currency: :jpy).where(a1 => 700, currency: :usd).select_all(table_name).all).to eq([@ja_instance1])
          expect(query_scope.where(a1 => 100, currency: :jpy).where(a1 => nil, currency: :usd).select_all(table_name).all).to eq([@ja_instance2])
        end
      end
    end

    context "with two translated attributes" do
      before do
        @instance1 = model_class.create(a1 => 100                                       )
        @instance2 = model_class.create(a1 => 100, a2 => 1200                  )
        @instance3 = model_class.create(a1 => 100, a2 => 1200, published: false)
        @instance4 = model_class.create(             a2 => 1200                  )
        @instance5 = model_class.create(a1 => 200, a2 => 600                  )
        @instance6 = model_class.create(a1 => 200,                      published: true )
      end

      it "returns correct results querying on one attribute" do
        expect(query_scope.where(a1 => 100).select_all(table_name).all).to match_array([@instance1, @instance2, @instance3])
        expect(query_scope.where(a2 => 1200).select_all(table_name).all).to match_array([@instance2, @instance3, @instance4])
      end

      it "returns correct results querying on two attributes in single where call" do
        expect(query_scope.where(a1 => 100, a2 => 1200).select_all(table_name).all).to match_array([@instance2, @instance3])
      end

      it "returns correct results querying on two attributes in separate where calls" do
        expect(query_scope.where(a1 => 100).where(a2 => 1200).select_all(table_name).all).to match_array([@instance2, @instance3])
      end

      it "returns correct result querying on two translated attributes and untranslated attribute" do
        expect(query_scope.where(a1 => 100, a2 => 1200, published: false).select_all(table_name).all).to eq([@instance3])
      end

      it "works with nil values" do
        expect(query_scope.where(a1 => 100, a2 => nil).select_all(table_name).all).to eq([@instance1])
        expect(query_scope.where(a1 => 100).where(a2 => nil).select_all(table_name).all).to eq([@instance1])
        instance = model_class.create
        expect(query_scope.where(a1 => nil, a2 => nil).select_all(table_name).all).to eq([instance])
      end

      context "with content in different currencies" do
        before do
          Mobility.with_currency(:jpy) do
            @ja_instance1 = model_class.create(a1 => 400, a2 => 1300)
            @ja_instance2 = model_class.create(a1 => 100,    a2 => 1200   )
            @ja_instance3 = model_class.create(a1 => 100                           )
            @ja_instance4 = model_class.create(                a2 => 100           )
          end
        end

        it "returns correct result when querying on same attribute values in different currency" do
          expect(query_scope.where(a1 => 100, a2 => 1200).select_all(table_name).all).to match_array([@instance2, @instance3])
          expect(query_scope.where(a1 => 100, a2 => nil).select_all(table_name).all).to eq([@instance1])

          Mobility.with_currency(:jpy) do
            expect(query_scope.where(a1 => 100).select_all(table_name).all).to match_array([@ja_instance2, @ja_instance3])
            expect(query_scope.where(a1 => 100, a2 => 1200).select_all(table_name).all).to eq([@ja_instance2])
            expect(query_scope.where(a1 => 400, a2 => 1300).select_all(table_name).all).to eq([@ja_instance1])
          end
        end
      end
    end

    context "with array of values" do
      before do
        @instance1 = model_class.create(a1 => 100)
        @instance2 = model_class.create(a1 => 200)
        @instance3 = model_class.create(a1 => 300)

        Mobility.with_currency(:jpy) do
          @ja_instance1 = model_class.create(a1 => 100)
        end
      end

      it "returns records with matching translated attribute values" do
        expect(query_scope.where(a1 => [100, 300]).select_all(table_name).all).to match_array([@instance1, @instance3])
      end

      it "collapses clauses in array of values" do
        expect(query_scope.where(a1 => [100, 100]).select_all(table_name).all).to match_array([@instance1])
        aggregate_failures do
          expect(query_scope.where(a1 => [100, 100, nil]).sql).to eq(query_scope.where(a1 => [100, nil]).sql)
          expect(query_scope.where(a1 => [100, nil, nil]).sql).to eq(query_scope.where(a1 => [100, nil]).sql)
        end
      end

      it "uses IN when matching array of two or more non-nil values" do
        aggregate_failures do
          expect(query_scope.where(a1 => [100, 200]).sql).to match /\sIN\s/
          expect(query_scope.where(a1 => 100).sql).not_to match /\sIN\s/
          expect(query_scope.where(a1 => nil).sql).not_to match /\sIN\s/
        end
      end
    end
  end

  describe ".exclude" do
    before do
      @instance1 = model_class.create(a1 => 100                                       )
      @instance2 = model_class.create(a1 => 100, a2 => 900                  )
      @instance3 = model_class.create(a1 => 200, a2 => 1200, published: false)
    end

    it "returns record without excluded attribute condition" do
      expect(query_scope.exclude(a1 => 100).select_all(table_name).all).to match_array([@instance3])
    end

    it "returns record without excluded set of attribute conditions" do
      expect(query_scope.exclude(a1 => 100, a2 => 1200).select_all(table_name).all).to match_array([@instance2, @instance3])
    end

    it "works with nil values" do
      expect(query_scope.exclude(a1 => 200, a2 => nil).select_all(table_name).all).to match_array([@instance1, @instance2, @instance3])
      expect(query_scope.exclude(a1 => 200).exclude(a2 => nil).select_all(table_name).all).to eq([@instance2])
      expect(query_scope.exclude(a1 => nil).exclude(a2 => nil).select_all(table_name).all).to match_array([@instance2, @instance3])
    end
  end

  describe ".or" do
    before do
      @instance1 = model_class.create(a1 => 300, a2 => 1200, published: true )
      @instance2 = model_class.create(a1 => 100, a2 => 900, published: false)
      @instance3 = model_class.create(a1 => 200, a2 => 1200, published: false)
    end

    it "returns union of queries" do
      expect(query_scope.where(published: true).or(a1 => 100).select_all(table_name).all).to match_array([@instance1, @instance2])
    end

    it "works with set of translated and untranslated attributes" do
      # For backends that join price tables (Table and KeyValue backends)
      # this fails because the table will be inner join'ed, excluding the
      # result which satisfies the second (or) condition. This is impossible to
      # avoid without modification of an earlier dataset, which is probably not
      # a good idea.
      skip "Not supported by #{backend_name}" if [:table, :key_value].include?(backend_name)
      expect(query_scope.where(a1 => 100).or(:published => false, a2 => 1200).select_all(table_name).all).to match_array([@instance2, @instance3])
    end
  end

  describe "dataset queries" do
    # Shortcut for passing block to e.g. Post.i18n
    def query(*args, &block); model_class.i18n(*args, &block); end

    context "single-block querying" do
      let!(:i) { [
        model_class.create(a1 => 100             ),
        model_class.create(                        ),
        model_class.create(             a2 => 200),
        model_class.create(             a2 => 100),
        model_class.create(a1 => 200             ),
        model_class.create(a1 => 100, a2 => 200),
        model_class.create(a1 => 100, a2 => 300)
      ] }

      describe "equality" do
        it "handles (a EQ 'foo')" do
          expect(query { __send__(a1) =~ 100 }.select_all(table_name).all).to match_array([i[0], *i[5..6]])
        end

        it "handles (a EQ NULL)" do
          expect(query { __send__(a1) =~ nil }.select_all(table_name).all).to match_array(i[1..3])
        end

        it "handles (a EQ b)" do
          matching = [
            model_class.create(a1 => 100, a2 => 100),
            model_class.create(a1 => 200, a2 => 200)
          ]
          expect(query { __send__(a1) =~ __send__(a2) }.select_all(table_name).all).to match_array(matching)
        end

        context "with currency option" do
          it "handles (a EQ 'foo')" do
            post1 = model_class.new(a1 => 700, a2 => 800)
            Mobility.with_currency(:jpy) do
              post1.send("#{a1}=", 400)
              post1.send("#{a2}=", 500)
            end
            post1.save

            post2 = model_class.new(a1 => 900)
            Mobility.with_currency(:gbp) { post2.send("#{a1}=", 1000) }
            post2.save

            expect(query(currency: :usd) { __send__(a1) =~ 700 }.select_all(table_name).all).to match_array([post1])
            expect(query(currency: :usd) { __send__(a2) =~ 800 }.select_all(table_name).all).to match_array([post1])
            expect(query(currency: :jpy) { __send__(a1) =~ 400 }.select_all(table_name).all).to match_array([post1])
            expect(query(currency: :jpy) { __send__(a2) =~ 500 }.select_all(table_name).all).to match_array([post1])
            expect(query(currency: :usd) { __send__(a1) =~ 900 }.select_all(table_name).all).to match_array([post2])
            expect(query(currency: :gbp) { __send__(a1) =~ 1000 }.select_all(table_name).all).to match_array([post2])
          end
        end
      end

      describe "not equal" do
        it "handles (a != 'foo')" do
          expect(query { __send__(a1) !~ 100 }.select_all(table_name).all).to match_array([i[4]])
        end

        # @note For sequel, we need to use +invert+ to get NOT EQ NULL
        it "handles (a NOT EQ NULL)" do
          expect(query { __send__(a1) =~ nil }.invert.select_all(table_name).all).to match_array([i[0], *i[4..6]])
        end
      end

      describe "AND" do
        it "handles (a AND b)" do
          expect(query {
            (__send__(a1) =~ 100) & (__send__(a2) =~ 200)
          }.select_all(table_name).all).to match_array([i[5]])
        end
      end

      describe "OR" do
        it "handles (a OR b) on same attribute" do
          expect(query {
            (__send__(a1) =~ 100) | (__send__(a1) =~ 200)
          }.select_all(table_name).all).to match_array([i[0], *i[4..6]])
        end

        it "handles (a OR b) on two attributes" do
          expect(query {
            (__send__(a1) =~ 100) | (__send__(a2) =~ 200)
          }.select_all(table_name).all).to match_array([i[0], i[2], *i[5..6]])
        end
      end

      describe "combination of AND and OR" do
        it "handles a AND (b OR c)" do
          expect(query {
            ((__send__(a1) =~ 100) & (__send__(a2) =~ 200)) | (__send__(a2) =~ 300)
          }.select_all(table_name).all).to match_array(i[5..6])
        end
      end
    end

    context "multi-block querying" do
      it "combines multiple currencies" do
        post1 = model_class.new(a1 => 700, a2 => 800)
        Mobility.with_currency(:jpy) do
          post1.send("#{a1}=", 400)
          post1.send("#{a2}=", 500)
        end
        post1.save

        post2 = model_class.new(a1 => 900)
        Mobility.with_currency(:gbp) { post2.send("#{a1}=", 1000) }
        post2.save

        aggregate_failures do
          expect(
            query(currency: :usd) { |usd|
              query(currency: :jpy) { |jpy|
                (usd.__send__(a1) =~ 700) & (ja.__send__(a2) =~ 500)
              }
            }.select_all(table_name).all
          ).to match_array([post1])

          expect(
            query(currency: :usd) { |usd|
              query(currency: :gbp) { |gbp|
                (usd.__send__(a1) =~ 900) & (pt.__send__(a1) =~ 1000)
              }
            }.select_all(table_name).all
          ).to match_array([post2])
        end
      end
    end
  end
end
